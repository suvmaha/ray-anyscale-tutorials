#!/usr/bin/env python3
"""
Concurrent load test for the Weather MCP Ray Serve deployment.

Usage:
  python3 load_test.py                                        # /health, localhost
  python3 load_test.py --url http://<lb-host>                 # AWS NLB
  python3 load_test.py --mcp --concurrency 20                 # MCP tool calls
  python3 load_test.py --duration 60 --concurrency 50 --mcp   # sustained load

Watch autoscaling in another terminal:
  kubectl get pods -l ray.io/cluster -w
  kubectl get rayservice weather-mcp -w
"""
import asyncio
import argparse
import time
from dataclasses import dataclass, field

import httpx

LOCATIONS = [
    ("CA", 37.7749, -122.4194),  # San Francisco
    ("NY", 40.7128, -74.0060),   # New York
    ("TX", 29.7604, -95.3698),   # Houston
    ("FL", 25.7617, -80.1918),   # Miami
    ("WA", 47.6062, -122.3321),  # Seattle
    ("IL", 41.8781, -87.6298),   # Chicago
    ("AZ", 33.4484, -112.0740),  # Phoenix
]


@dataclass
class Stats:
    success: int = 0
    failure: int = 0
    latencies: list = field(default_factory=list)


async def hit_health(client: httpx.AsyncClient, base_url: str, stats: Stats) -> None:
    t0 = time.perf_counter()
    try:
        resp = await client.get(f"{base_url}/health", timeout=10.0)
        resp.raise_for_status()
        stats.success += 1
        stats.latencies.append(time.perf_counter() - t0)
    except Exception as exc:
        stats.failure += 1
        print(f"  [health] {exc}")


async def hit_mcp_forecast(
    client: httpx.AsyncClient, base_url: str, lat: float, lon: float, stats: Stats
) -> None:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "get_forecast",
            "arguments": {"latitude": lat, "longitude": lon},
        },
    }
    t0 = time.perf_counter()
    try:
        resp = await client.post(
            f"{base_url}/mcp",
            json=payload,
            timeout=30.0,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        resp.raise_for_status()
        stats.success += 1
        stats.latencies.append(time.perf_counter() - t0)
    except Exception as exc:
        stats.failure += 1
        print(f"  [mcp] {exc}")


async def run(base_url: str, concurrency: int, duration: int, use_mcp: bool) -> None:
    stats = Stats()
    deadline = time.monotonic() + duration
    batch = 0

    async with httpx.AsyncClient() as client:
        while time.monotonic() < deadline:
            tasks = []
            for i in range(concurrency):
                if use_mcp:
                    _, lat, lon = LOCATIONS[i % len(LOCATIONS)]
                    tasks.append(hit_mcp_forecast(client, base_url, lat, lon, stats))
                else:
                    tasks.append(hit_health(client, base_url, stats))
            await asyncio.gather(*tasks)
            batch += 1
            if batch % 5 == 0:
                elapsed = duration - (deadline - time.monotonic())
                rps = stats.success / max(elapsed, 1)
                print(
                    f"  t={elapsed:.0f}s  "
                    f"ok={stats.success}  fail={stats.failure}  rps={rps:.1f}"
                )

    total = stats.success + stats.failure
    if stats.latencies:
        sl = sorted(stats.latencies)
        avg_ms = sum(sl) / len(sl) * 1000
        p95_ms = sl[int(len(sl) * 0.95)] * 1000
        p99_ms = sl[int(len(sl) * 0.99)] * 1000
    else:
        avg_ms = p95_ms = p99_ms = 0.0

    print()
    print("── Results ─────────────────────────────────────────────────────────")
    print(f"  Requests  : {total} ({stats.success} ok, {stats.failure} failed)")
    print(f"  Avg       : {avg_ms:.1f} ms")
    print(f"  p95       : {p95_ms:.1f} ms")
    print(f"  p99       : {p99_ms:.1f} ms")
    print()
    print("Watch Ray Serve autoscaling:")
    print("  kubectl get pods -l ray.io/cluster -w")
    print("  kubectl get rayservice weather-mcp -w")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Load test the Weather MCP Ray Serve deployment"
    )
    parser.add_argument(
        "--url", default="http://localhost:8000", help="Base URL (default: localhost:8000)"
    )
    parser.add_argument(
        "--concurrency", type=int, default=10, help="Concurrent requests per batch"
    )
    parser.add_argument(
        "--duration", type=int, default=30, help="Test duration in seconds"
    )
    parser.add_argument(
        "--mcp", action="store_true", help="Use MCP forecast endpoint instead of /health"
    )
    args = parser.parse_args()

    endpoint = "/mcp (get_forecast)" if args.mcp else "/health"
    print(f"Target : {args.url}{endpoint}")
    print(f"Load   : concurrency={args.concurrency}  duration={args.duration}s")
    print()

    asyncio.run(run(args.url, args.concurrency, args.duration, args.mcp))
