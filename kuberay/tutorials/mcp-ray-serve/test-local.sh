#!/usr/bin/env bash
# test-local.sh — Run Weather MCP locally with Ray Serve and smoke-test it.
# No EKS needed. Requires Python 3.10+ with pip.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "── Installing dependencies ──────────────────────────────────────────────"
pip install --quiet \
    "ray[serve]>=2.44.0" \
    "mcp[cli]>=1.2.0" \
    "httpx>=0.24.0" \
    "pydantic>=2.0.0" \
    "fastapi>=0.115.0"

echo "── Starting Ray Serve locally ───────────────────────────────────────────"
cd "${SCRIPT_DIR}"
serve run weather_mcp_ray:app &
SERVE_PID=$!
echo "Serve PID: ${SERVE_PID} — waiting for startup..."
sleep 8

echo ""
echo "── Health check ─────────────────────────────────────────────────────────"
curl -sf http://localhost:8000/health | python3 -m json.tool

echo ""
echo "── MCP: get_forecast (San Francisco 37.77, -122.42) ────────────────────"
python3 - <<'PYEOF'
import httpx, json

payload = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
        "name": "get_forecast",
        "arguments": {"latitude": 37.7749, "longitude": -122.4194},
    },
}
resp = httpx.post("http://localhost:8000/mcp", json=payload, timeout=30.0)
resp.raise_for_status()
result = resp.json()
if "result" in result:
    for item in result["result"].get("content", []):
        text = item.get("text", "")
        print(text[:600] + "\n..." if len(text) > 600 else text)
else:
    print(json.dumps(result, indent=2))
PYEOF

echo ""
echo "── MCP: get_alerts (California) ────────────────────────────────────────"
python3 - <<'PYEOF'
import httpx, json

payload = {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
        "name": "get_alerts",
        "arguments": {"state": "CA"},
    },
}
resp = httpx.post("http://localhost:8000/mcp", json=payload, timeout=30.0)
resp.raise_for_status()
result = resp.json()
if "result" in result:
    for item in result["result"].get("content", []):
        text = item.get("text", "")
        print(text[:400] + "\n..." if len(text) > 400 else text)
else:
    print(json.dumps(result, indent=2))
PYEOF

echo ""
echo "── Quick load test (10s, /health) ──────────────────────────────────────"
python3 "${SCRIPT_DIR}/load_test.py" --duration 10 --concurrency 5

echo ""
echo "── Quick load test (10s, MCP forecasts) ────────────────────────────────"
python3 "${SCRIPT_DIR}/load_test.py" --duration 10 --concurrency 5 --mcp

echo ""
echo "── Stopping Ray Serve ───────────────────────────────────────────────────"
kill "${SERVE_PID}" 2>/dev/null || true
serve shutdown -y 2>/dev/null || ray stop 2>/dev/null || true
echo "Done."
