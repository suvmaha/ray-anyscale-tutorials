# Cluster

Creates an EKS Auto Mode cluster for running Ray and Anyscale workloads.

## What Gets Created

| Resource | Detail |
|----------|--------|
| EKS cluster | Auto Mode, Kubernetes 1.35 |
| Node management | Karpenter (managed by AWS via Auto Mode) |
| VPC | Provisioned by CDK in `infra/` — 2 AZs, public + private subnets |
| GPU NodePool | Optional — `g6` instances (NVIDIA L4), apply when tutorials need GPUs |

Nodes scale to zero when idle. New nodes provision automatically when workloads are scheduled.

> **Note:** EKS Auto Mode provisions nodes on demand — Karpenter spins them up when workloads are scheduled and terminates them when idle. You may or may not see nodes immediately after cluster creation depending on bootstrap activity.

## Why This Cluster for Ray and Anyscale

Ray distributes Python workloads across a cluster of machines. Anyscale manages that cluster — scheduling jobs, scaling workers, persisting logs. EKS is where those Ray workers actually run.

- **Anyscale path** — register this cluster with `../anyscale/setup.sh`. Anyscale's control plane manages Ray workloads remotely over HTTPS. Your data stays in your AWS account.
- **KubeRay path** — install the open-source Ray operator with `../kuberay/install.sh`. Full control, no Anyscale account needed.

## Scripts

```bash
./cluster/create.sh                          # Deploy VPC (CDK) + create EKS cluster
INSTALL_GPU_NODEPOOL=true ./cluster/create.sh  # Same + apply GPU NodePool for LLM tutorials
./cluster/destroy.sh                         # Tear down cluster + VPC
```

## Next Steps

```bash
# Anyscale path
./anyscale/setup.sh

# KubeRay path
./kuberay/install.sh
```
