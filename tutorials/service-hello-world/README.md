# Tutorial 03 — Hello World Service

Deploy your first always-on REST endpoint with Ray Serve on Anyscale. Unlike jobs (run once, exit), services stay up and handle requests continuously — this is the Anyscale Services model.

## What It Does

A FastAPI app wrapped in a Ray Serve deployment, exposing two endpoints:
- `GET /hello?name=<name>` → `"Hello <name>!"`
- `GET /health` → `{"status": "ok"}`

## Prerequisites

- EKS cluster running — `./cluster/create.sh`
- Anyscale connected — `./anyscale/setup.sh`

## Deploy

```bash
./tutorials/service-hello-world/deploy.sh
```

The deploy output prints a line like:
```
curl -H "Authorization: Bearer <TOKEN>" <BASE_URL>
```

## Query

```bash
python tutorials/service-hello-world/query.py --token <TOKEN> --url <BASE_URL>
```

## Monitor

**console.anyscale.com/services** — shows replicas, traffic, rollout status.

```bash
anyscale service status --name service-hello-world
```

## Terminate

Services stay up until you explicitly stop them — terminate before teardown:

```bash
anyscale service terminate --name service-hello-world
```

## Jobs vs Services

| | Jobs | Services |
|-|------|---------|
| Lifecycle | Run once, exit | Always on |
| Entry point | `anyscale job submit` | `anyscale service deploy` |
| Config | `job.yaml` | `service.yaml` |
| Use case | Batch processing | Online inference APIs |

## What's Next

- **Tutorial 04** — Deploy Llama 3.1 8B as an OpenAI-compatible API (Ray Serve LLM)
