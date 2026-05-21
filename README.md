# Ray & Anyscale Tutorials on AWS EKS

Hands-on tutorials for Distributed AI with Ray and Anyscale on Amazon EKS. One base cluster, two paths — open-source KubeRay or managed Anyscale — each tutorial chooses its path.

## Two Paths, One Cluster

```
./cluster/create.sh
        ↓
┌───────────────────┬───────────────────────┐
│   KubeRay Path    │    Anyscale Path       │
│  (open source)    │  (managed platform)    │
│                   │                        │
│ cluster/          │ anyscale/              │
│   smoke-test.sh   │   setup.sh            │
│                   │   teardown.sh         │
│ tutorials/        │ tutorials/             │
│   mcp-ray-serve/  │   llm-batch-inference/│
└───────────────────┴───────────────────────┘
        ↓
./cluster/destroy.sh
```

## Repository Layout

```
ray-anyscale-tutorials/
├── infra/                        CDK VPC stack (2 AZs, 1 NAT gateway)
├── cluster/                      EKS cluster lifecycle
│   ├── cluster.yaml.template     eksctl EKS Auto Mode config
│   ├── create.sh                 CDK + eksctl + optional KubeRay
│   ├── smoke-test.sh             Verify KubeRay is working
│   └── destroy.sh                Full teardown
├── anyscale/                     Anyscale platform setup
│   ├── setup.sh                  anyscale cloud setup on EKS
│   └── teardown.sh               anyscale cloud delete + cleanup
└── tutorials/
    ├── mcp-ray-serve/            KubeRay: FastMCP server on Ray Serve
    └── llm-batch-inference/      Anyscale: LLM batch processing at scale
```

## Prerequisites

| Tool | Purpose |
|------|---------|
| AWS CLI | configured for your account |
| eksctl ≥ 0.195 | EKS cluster creation |
| kubectl | Kubernetes operations |
| helm ≥ 3 | Operator installation |
| docker | Tutorial image builds (KubeRay path) |
| Python 3.10+ | CDK, Anyscale CLI |
| anyscale CLI | `pip install -U anyscale` (Anyscale path) |

## KubeRay Path

```bash
# 1. Create cluster with KubeRay
INSTALL_KUBERAY=true ./cluster/create.sh

# 2. Verify
./cluster/smoke-test.sh

# 3. Deploy tutorial
./tutorials/mcp-ray-serve/deploy.sh

# 4. Clean up tutorial
./tutorials/mcp-ray-serve/cleanup.sh

# 5. Tear down cluster
./cluster/destroy.sh
```

## Anyscale Path

```bash
# 1. Create cluster (no KubeRay)
./cluster/create.sh

# 2. Wire Anyscale to the cluster
./anyscale/setup.sh

# 3. Submit tutorial job
./tutorials/llm-batch-inference/submit.sh

# 4. Remove Anyscale
./anyscale/teardown.sh

# 5. Tear down cluster
./cluster/destroy.sh
```

## Tutorials

| Tutorial | Path | Ray Library | Blog |
|----------|------|-------------|------|
| [mcp-ray-serve](tutorials/mcp-ray-serve/) | KubeRay | Ray Serve | AI-ML on AWS #8 |
| [llm-batch-inference](tutorials/llm-batch-inference/) | Anyscale | Ray Data | AI-ML on AWS #7 |

## Cost

| Resource | Rate |
|----------|------|
| NAT gateway | ~$1/day |
| EKS control plane | ~$0.10/hr |
| EC2 nodes | Per use, scale to zero when idle |

Run `./cluster/destroy.sh` when done to stop all charges.
