# LLM Batch Inference

Classify 10,000 company names by industry using Llama-3.1-8B-Instruct and Ray Data on a GPU worker. Shows the pattern for GPU-accelerated batch LLM inference at scale on Anyscale + EKS.

## What It Does

1. Loads a 2M-row CSV of company names from S3, takes 10,000 rows
2. Repartitions into 128 blocks for parallel processing
3. Sends each company name to Llama-3.1-8B-Instruct: *"What industry is this company in?"*
4. Classifies into one of 9 categories: Law Firm, Healthcare, Technology, Retail, Consulting, Manufacturing, Finance, Real Estate, Other
5. Prints 3 sample results

```python
{'Company': 'Acme Health Partners', 'inferred_industry': 'Healthcare', ...}
```

**Ray Data** distributes the dataset. **vLLM** runs inference with `concurrency=4` (4 parallel inference instances per GPU worker).

## Prerequisites

- EKS cluster running — `./cluster/create.sh`
- Anyscale connected — `./anyscale/setup.sh`
- AWS account G-instance vCPU quota ≥ 8 (see [Quota Note](#aws-gpu-quota-note) below)

## Step 1 — Add GPU NodePool

If you created the cluster without `INSTALL_GPU_NODEPOOL=true`, add the GPU NodePool now:

```bash
kubectl apply -f cluster/gpu-nodepool.yaml
kubectl apply -f cluster/nvidia-device-plugin.yaml
```

Verify:

```bash
kubectl get nodepools
# should show: gpu-node-pool   Ready
```

> If you created the cluster with `INSTALL_GPU_NODEPOOL=true ./cluster/create.sh`, the NodePool is already present — skip this step.

## Step 2 — Run

```bash
./tutorials/llm-batch-inference/submit.sh
```

Monitor at **console.anyscale.com/jobs**. Expect ~10-15 min for the GPU worker to pull the image and load the model before inference begins.

## Compute Config

| Node | Type | Size |
|------|------|------|
| Head | CPU only | 8 CPU, 32 GiB |
| Worker | NVIDIA L4 GPU | 4 CPU, 16 GiB, 1x L4 |

Karpenter provisions a `g6.2xlarge` (8 vCPU, 32 GiB, 1x NVIDIA L4) for each GPU worker. Workers scale from 0 to 10 based on Ray task demand.

## AWS GPU Quota Note

The default AWS quota for G-instance vCPUs is 8 (`Running On-Demand G and VT instances`). A single `g6.2xlarge` uses all 8 vCPUs — only 1 GPU worker can run at a time unless you request a quota increase via the [Service Quotas console](https://console.aws.amazon.com/servicequotas/).

## Reference

### Job commands

```bash
# List all jobs (use ID when multiple runs share the same name)
anyscale job list

# Status by name (fails if multiple runs exist — use ID instead)
anyscale job status --name llm-batch-inference

# Status by ID
anyscale job status --id <prodjob_xxx>

# Stream logs by ID
anyscale job logs --id <prodjob_xxx> --follow

# Terminate
anyscale job terminate --name llm-batch-inference
anyscale job terminate --id <prodjob_xxx>
```

### Monitor GPU node provisioning

```bash
# Watch Karpenter provision the GPU node (g6.2xlarge appears here)
kubectl get nodeclaims -w

# Static snapshot
kubectl get nodeclaims
```

### Monitor pods

```bash
# Watch pod lifecycle (Pending → Init → Running)
kubectl get pods -n anyscale-operator -w

# Static snapshot
kubectl get pods -n anyscale-operator
```

### Ray cluster resource state

```bash
# Full view: nodes, pending demands, resource usage
# Replace pod name with the head pod (6/6 Running, no GPU)
kubectl exec -it <head-pod> -n anyscale-operator -c ray -- ray status
```

Use `ray status` to confirm:
- GPU worker joined the Ray cluster (`FP-4CPU-16GB-1GPU-L4` in Active)
- `1.0/1.0 GPU` consumed (model loaded, inference running)
- No stuck pending demands

### Debug a stuck or pending pod

```bash
# Events show image pull progress, scheduling failures, GPU allocation
kubectl describe pod <pod-name> -n anyscale-operator | grep -A 20 "Events:"
```

### NVIDIA device plugin health

```bash
# Should show Running on the GPU node, CrashLoopBackOff on CPU-only nodes (expected)
kubectl get pods -n kube-system | grep nvidia
```

### Karpenter logs

```bash
# Live provisioning decisions
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Filter for GPU scheduling errors
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --since=120s \
  | grep -i "error\|gpu\|g6\|nodeclaim"
```

### NodePool status

```bash
kubectl get nodepools
kubectl apply -f cluster/gpu-nodepool.yaml   # update NodePool config
```

### Common debugging sequence

```bash
# 1. Check job state
anyscale job status --id <prodjob_xxx>

# 2. Check if GPU node was provisioned
kubectl get nodeclaims

# 3. Check pod state
kubectl get pods -n anyscale-operator

# 4. Describe a stuck pod (scheduling errors, image pull status)
kubectl describe pod <pod-name> -n anyscale-operator | grep -A 20 "Events:"

# 5. Check Ray cluster resource state (is GPU allocated? any pending demands?)
kubectl exec -it <head-pod> -n anyscale-operator -c ray -- ray status

# 6. Check Karpenter for GPU scheduling errors
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --since=120s \
  | grep -i "error\|gpu\|g6"
```

---

## What's Next

- **Hello World Service** — Ray Serve + Anyscale Services, CPU
