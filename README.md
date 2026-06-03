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
│   ├── create.sh                           CDK + eksctl + Karpenter Helm install
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
| Python 3.11 | CDK, Anyscale CLI |
| anyscale CLI | `pipx install anyscale` (Anyscale path) |

## Anyscale Path

```bash
# 1. Create cluster
./cluster/create.sh

# 2. Wire Anyscale to the cluster
./anyscale/setup.sh

# 3. Submit tutorial job (Tutorial 01 — Hello World)
./tutorials/job-hello-world/submit.sh

# 4. Remove Anyscale
./anyscale/teardown.sh

# 5. Tear down cluster
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

| Tutorial | Path | Ray Library | Blog |
|----------|------|-------------|------|
| [job-hello-world](tutorials/job-hello-world/) | Anyscale | Ray Core | Tutorial 01 |
| [llm-batch-inference](tutorials/llm-batch-inference/) | Anyscale | Ray Data | Tutorial 02 |
| [mcp-ray-serve](kuberay/tutorials/mcp-ray-serve/) | KubeRay | Ray Serve | Tutorial 03 |

## Cost

| Resource | Rate |
|----------|------|
| NAT gateway | ~$1/day |
| EKS control plane | ~$0.10/hr |
| EC2 nodes | Per use, scale to zero when idle |

Run `./cluster/destroy.sh` when done to stop all charges.
