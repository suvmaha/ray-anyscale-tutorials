# Ray Anyscale Tutorials on AWS EKS

Hands-on tutorials deploying open-source Ray workloads on Amazon EKS. Each tutorial shares one base cluster and deploys its own workload independently — create the cluster once, run any tutorial, clean up the workload, repeat.

## Architecture Pattern

```
One base cluster (EKS Auto Mode + KubeRay)
├── Tutorial 01 — MCP Ray Serve (weather MCP server, CPU autoscaling)
├── Tutorial 02 — Ray Data       (coming soon)
├── Tutorial 03 — Ray Train + GPU (coming soon)
└── ...
```

**Infrastructure:**
- **EKS Auto Mode** — AWS-managed Karpenter; nodes scale to zero when idle
- **KubeRay** — Kubernetes operator adding `RayCluster`, `RayJob`, `RayService` CRDs
- **CDK (Python)** — VPC-only stack (2 AZs, 1 NAT gateway)

## Prerequisites

| Tool | Min version |
|------|-------------|
| AWS CLI | configured for your account |
| eksctl | ≥ 0.195 |
| kubectl | any recent |
| helm | ≥ 3 |
| docker | for tutorial image builds |
| Python | 3.10+ |

## Cluster Lifecycle

**Create (one time per series):**
```bash
./scripts/create-cluster.sh
```

**Smoke test:**
```bash
./scripts/smoke-test.sh
```

**Destroy (when done with all tutorials):**
```bash
./scripts/destroy-cluster.sh
```

## Tutorials

| # | Title | Ray Library | GPU | Local test |
|---|-------|-------------|-----|-----------|
| [01](tutorials/01-mcp-ray-serve/) | MCP Ray Serve — Weather Server | Ray Serve | No | Yes |

## Repository Layout

```
ray-anyscale-tutorials/
├── infra/                       CDK VPC stack
│   ├── app.py
│   └── eks_ray/eks_ray_stack.py
├── cluster/
│   └── cluster.yaml.template    eksctl EKS Auto Mode config
├── scripts/
│   ├── create-cluster.sh        CDK + eksctl + KubeRay install
│   ├── smoke-test.sh            Verify KubeRay works
│   └── destroy-cluster.sh      Full teardown
└── tutorials/
    └── 01-mcp-ray-serve/        Tutorial 1 workload
        ├── weather_mcp_ray.py   FastMCP + Ray Serve app
        ├── Dockerfile
        ├── ray-service.yaml.template
        ├── deploy.sh
        ├── cleanup.sh
        ├── test-local.sh
        ├── load_test.py
        └── locustfile.py
```

## Cost

| Resource | Rate |
|----------|------|
| NAT gateway | ~$1/day |
| EKS control plane | ~$0.10/hr |
| EC2 nodes | Per use, scale to zero when idle |

Run `./scripts/destroy-cluster.sh` when done to stop all charges.
