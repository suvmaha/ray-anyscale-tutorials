# Tutorials

All tutorials run on the same EKS cluster. Start with CPU tutorials, add the GPU NodePool when ready for LLM workloads.

**Command reference:** [reference-anyscale-commands/](reference-anyscale-commands/) — job status, logs, terminate, service management, Karpenter debugging.

---

## Hello World Job

Submit 100 parallel Ray tasks as proof the cluster works.

```bash
./tutorials/job-hello-world/submit.sh
```

**Compute:** CPU only — no GPU NodePool needed

---

## LLM Batch Inference

Classify 10,000 company names by industry using Llama 3.1 8B + vLLM + Ray Data.

```bash
./tutorials/llm-batch-inference/submit.sh
```

**Compute:** 1x NVIDIA L4 GPU — requires GPU NodePool:
```bash
kubectl apply -f cluster/gpu-nodepool.yaml
kubectl apply -f cluster/nvidia-device-plugin.yaml
```

---

## Hello World Service

Deploy an always-on REST endpoint with Ray Serve on Anyscale Services.

```bash
./tutorials/service-hello-world/deploy.sh
```

**Compute:** CPU only — terminate before teardown:
```bash
anyscale service terminate --name service-hello-world
```

---

## Running Multiple Tutorials

Services stay up until terminated — jobs exit on their own. Sequence for a full session:

```bash
# CPU tutorials
./tutorials/job-hello-world/submit.sh
./tutorials/service-hello-world/deploy.sh

# Add GPU NodePool, then GPU tutorials
kubectl apply -f cluster/gpu-nodepool.yaml
kubectl apply -f cluster/nvidia-device-plugin.yaml
./tutorials/llm-batch-inference/submit.sh

# Terminate services before teardown
anyscale service terminate --name service-hello-world
```
