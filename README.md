# Ray & Anyscale Tutorials on AWS EKS

Hands-on tutorials for Distributed AI with Ray and Anyscale on Amazon EKS. One base cluster, two paths — open-source KubeRay or managed Anyscale — each tutorial chooses its path.

## Two Paths, One Cluster

```
./cluster/create.sh
        ↓
┌───────────────────────┬───────────────────────┐
│     KubeRay Path      │    Anyscale Path       │
│    (open source)      │  (managed platform)    │
│                       │                        │
│ kuberay/              │ anyscale/              │
│   install.sh          │   setup.sh             │
│   smoke-test.sh       │   teardown.sh          │
│   tutorials/          │                        │
│     mcp-ray-serve/    │ tutorials/             │
│                       │   llm-batch-inference/ │
└───────────────────────┴───────────────────────┘
        ↓
./cluster/destroy.sh
```

## Repository Layout

```
ray-anyscale-tutorials/
├── infra/                        CDK VPC stack (2 AZs, 1 NAT gateway)
├── cluster/                                EKS cluster lifecycle
│   ├── cluster.yaml.template               eksctl cluster config (system node group + Karpenter IRSA)
│   ├── karpenter-iam-policy.json.template  IAM policy for Karpenter controller
│   ├── karpenter-nodepool.yaml.template    EC2NodeClass + Anyscale NodePool
│   ├── gpu-nodepool.yaml                   Optional GPU NodePool (g6/L4)
│   ├── create.sh                           CDK + eksctl + Karpenter + nginx ingress
│   └── destroy.sh                          EKS cluster + VPC teardown
├── anyscale/                     Anyscale platform setup
│   ├── setup.sh                  Register EKS cluster with Anyscale
│   └── teardown.sh               Deregister cluster + cleanup
├── kuberay/                      KubeRay operator + tutorials
│   ├── install.sh                Install KubeRay operator via Helm
│   ├── smoke-test.sh             Verify KubeRay is working
│   └── tutorials/
│       └── mcp-ray-serve/        FastMCP server on Ray Serve
└── tutorials/                    Anyscale tutorials
    └── llm-batch-inference/      LLM batch processing at scale
```

## Prerequisites

| Tool | Purpose |
|------|---------|
| AWS CLI | configured for your account |
| eksctl ≥ 0.195 | EKS cluster creation |
| kubectl | Kubernetes operations |
| helm ≥ 3 | Operator installation |
| docker | Tutorial image builds (KubeRay path) |
| Python 3.11+ | CDK, Anyscale CLI, tutorial scripts |
| anyscale CLI | `pipx install anyscale` (Anyscale path) |

### Local Python Setup

Tutorial query scripts (`query.py`, etc.) need a local venv with `requests`:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

After activation `python` and `python3` both work. The `.venv/` directory is gitignored.

## Anyscale Path

```bash
# 1. Create cluster
./cluster/create.sh

# 2. Wire Anyscale to the cluster
./anyscale/setup.sh

# 3. Run tutorials
#    See tutorials/README.md for the full list

# 4. Terminate any running services before teardown
anyscale service list
anyscale service terminate --name <service-name>

# 5. Remove Anyscale
./anyscale/teardown.sh

# 6. Tear down cluster
./cluster/destroy.sh
```

## KubeRay Path

```bash
# 1. Create cluster
./cluster/create.sh

# 2. Install KubeRay operator
./kuberay/install.sh

# 3. Verify
./kuberay/smoke-test.sh

# 4. Deploy tutorial
./kuberay/tutorials/mcp-ray-serve/deploy.sh

# 5. Clean up tutorial
./kuberay/tutorials/mcp-ray-serve/cleanup.sh

# 6. Tear down cluster
./cluster/destroy.sh
```

## GPU NodePool (for LLM tutorials)

```bash
# Apply after cluster creation when tutorials require GPUs
INSTALL_GPU_NODEPOOL=true ./cluster/create.sh
```

Provisions `g6` instances (NVIDIA L4 GPU) via Karpenter. Scales to zero when idle — no cost when not in use.

## Tutorials

| Tutorial | Path | Ray Library | Notes |
|----------|------|-------------|-------|
| [job-hello-world](tutorials/job-hello-world/) | Anyscale | Ray Core | CPU only |
| [llm-batch-inference](tutorials/llm-batch-inference/) | Anyscale | Ray Data + vLLM | GPU required |
| [service-hello-world](tutorials/service-hello-world/) | Anyscale | Ray Serve | Always-on REST API |
| [mcp-ray-serve](kuberay/tutorials/mcp-ray-serve/) | KubeRay | Ray Serve | FastMCP server |

## Cost

| Resource | Rate |
|----------|------|
| NAT gateway | ~$1/day |
| EKS control plane | ~$0.10/hr |
| EC2 nodes | Per use, scale to zero when idle |

Run `./cluster/destroy.sh` when done to stop all charges.
