# Tutorial 01 — MCP Ray Serve: Weather Server

Deploy a [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server on Ray Serve and watch it autoscale under concurrent load.

## What You'll Build

- A FastMCP weather server wrapping the National Weather Service (NWS) free API
- Deployed via KubeRay `RayService` on EKS Auto Mode
- Exposed through an AWS Network Load Balancer
- Autoscales from 2 → 20 replicas as MCP traffic increases

## Architecture

```
MCP Client ──POST /mcp──▶ NLB ──▶ Ray Serve Replicas (FastMCP)
                                        └── RayCluster (EKS Auto Mode)
```

Ray Serve manages replica autoscaling based on in-flight requests per replica. When replicas fill up, Ray Serve spawns more (up to `max_replicas=20`). When load drops, it scales back down.

## MCP Transport: Streamable HTTP

This tutorial uses **Streamable HTTP** (not stdio), which is the production MCP transport:

| Mode | Use case |
|------|----------|
| stdio | Local tools, single-user, Claude Desktop |
| Streamable HTTP | Remote servers, multi-client, scalable |

`stateless_http=True` on the FastMCP server means no session affinity is required — any replica can handle any request, enabling true horizontal scaling.

**Endpoints:**
- `POST /mcp` — MCP JSON-RPC 2.0 (tool calls, resource reads)
- `GET /health` — Liveness probe + load test target

## MCP Tools

| Tool | Args | Description |
|------|------|-------------|
| `get_alerts` | `state: str` | Active NWS weather alerts for a US state (e.g. `"CA"`) |
| `get_forecast` | `latitude: float, longitude: float` | 5-period forecast for coordinates |

## Local Test (no EKS needed)

```bash
./test-local.sh
```

Installs dependencies, starts Ray Serve locally at `http://localhost:8000`, runs MCP tool calls, runs a 10-second load test.

## EKS Deployment

**Prerequisite:** base cluster must be running.

```bash
# Create the cluster (one time)
../../scripts/create-cluster.sh

# Deploy Tutorial 1
./deploy.sh
```

After deployment, get the load balancer hostname:

```bash
kubectl get svc weather-mcp-serve-svc
```

## Load Testing

```bash
# Async Python — /health endpoint
python3 load_test.py --url http://<lb-host> --concurrency 30 --duration 60

# Async Python — real MCP tool calls
python3 load_test.py --url http://<lb-host> --mcp --concurrency 20 --duration 60

# Locust web UI (open http://localhost:8089)
pip install locust
locust -f locustfile.py --host http://<lb-host>
```

## Watch Autoscaling

```bash
# Pods scaling up/down
kubectl get pods -l ray.io/cluster -w

# RayService status
kubectl get rayservice weather-mcp -w

# Ray dashboard (port-forward)
kubectl port-forward svc/weather-mcp-head-svc 8265:8265
# Then open http://localhost:8265
```

## Cleanup

```bash
./cleanup.sh
```

Removes the RayService (and its NLB) from the cluster. The cluster itself stays running for other tutorials.

## Files

| File | Purpose |
|------|---------|
| `weather_mcp_ray.py` | FastMCP server + Ray Serve deployment definition |
| `Dockerfile` | Container image built on `rayproject/ray:2.44.0` |
| `ray-service.yaml.template` | KubeRay RayService spec (`${ECR_IMAGE}` filled by deploy.sh) |
| `deploy.sh` | ECR build/push + envsubst + kubectl apply |
| `cleanup.sh` | Delete RayService from cluster |
| `test-local.sh` | Local smoke test (no EKS required) |
| `load_test.py` | Async concurrent load test script |
| `locustfile.py` | Locust web UI load test |
