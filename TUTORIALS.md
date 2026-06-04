# Tutorial Map — AI Architect on Ray & Anyscale

This is the master curriculum for this repo. Each tutorial runs on the same EKS cluster. The goal: cover every major layer of the modern AI stack — serving, batch inference, training, agent frameworks, and observability — using Ray and Anyscale as the compute backbone.

---

## The Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    Your Applications                            │
│   LangChain · LangGraph · Strands · AgentCore · FastAPI        │
├─────────────────────────────────────────────────────────────────┤
│                  Ray Libraries                                  │
│   Ray Serve · Ray Data · Ray Train · Ray Core · RLlib           │
├─────────────────────────────────────────────────────────────────┤
│               Anyscale Platform (BYOK)                          │
│   Jobs · Services · Autoscaling · Observability · Console       │
├─────────────────────────────────────────────────────────────────┤
│              EKS + Karpenter (this repo)                        │
│   g6/L4 GPU nodes · m-family CPU nodes · Scale to zero          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tutorial Registry

### 01 — Ray Core: Jobs

| # | Tutorial | What It Demonstrates | Compute | Source | Status |
|---|----------|---------------------|---------|--------|--------|
| 01 | [job-hello-world](tutorials/job-hello-world/) | Submit a Ray job, parallel tasks, Anyscale Jobs UI | CPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/job_hello_world) | ✅ Done |
| 02 | spark-on-ray | Run Apache Spark on Ray with RayDP — Iris dataset, SQL queries, groupBy | CPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/spark_on_ray) | Planned |

---

### 02 — Ray Data: Batch Processing

| # | Tutorial | What It Demonstrates | Compute | Source | Status |
|---|----------|---------------------|---------|--------|--------|
| 03 | [llm-batch-inference](tutorials/llm-batch-inference/) | Classify 10K companies with Llama 3.1 8B + vLLM + Ray Data | 1x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/job_hello_world) | 🔄 Testing |
| 04 | image-batch-inference | Process images at scale with a Vision Language Model | 1x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/image_processing) | Planned |
| 05 | text-data-pipeline | Large-scale text dedup and quality filtering with Data-Juicer | CPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/fineweb_dedup) | Planned |

---

### 03 — Ray Serve: Online Serving (Anyscale Services)

| # | Tutorial | What It Demonstrates | Compute | Source | Status |
|---|----------|---------------------|---------|--------|--------|
| 06 | service-hello-world | Deploy a REST endpoint with Ray Serve, Anyscale Services lifecycle | CPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/service_hello_world) | Planned |
| 07 | deploy-llama-3-8b | OpenAI-compatible API for Llama 3.1 8B via Ray Serve LLM | 1x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/deploy_llama_3_8b) | Planned |
| 08 | deploy-llama-3-70b | Serve Llama 3.1 70B with tensor parallelism across multiple GPUs | 4x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/deploy_llama_3_1_70b) | Needs quota |
| 09 | sglang-inference | Multi-node LLM inference with SGLang — higher throughput than vLLM | 2x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/sglang_inference) | Needs quota |

---

### 04 — Agent Frameworks on Ray

| # | Tutorial | What It Demonstrates | Compute | Source | Status |
|---|----------|---------------------|---------|--------|--------|
| 10 | langchain-on-ray | Run LangChain agents as Ray jobs — parallel tool calls, shared state | CPU | [LangChain docs](https://python.langchain.com/docs/integrations/providers/ray_serve/) | Planned |
| 11 | langgraph-on-ray | Distribute LangGraph workflow nodes across Ray workers | CPU | [LangGraph docs](https://langchain-ai.github.io/langgraph/) | Planned |
| 12 | strands-on-ray | AWS Strands agents submitting Ray jobs as tools | CPU | [Strands SDK](https://github.com/strands-agents/sdk-python) | Planned |
| 13 | agentcore-with-anyscale | AgentCore calling an Anyscale Service as an MCP/tool endpoint | 1x L4 GPU | Custom | Planned |

---

### 05 — Ray Train: Fine-Tuning

| # | Tutorial | What It Demonstrates | Compute | Source | Status |
|---|----------|---------------------|---------|--------|--------|
| 14 | fine-tune-llm | Fine-tune Llama 3.1 8B with LoRA + HuggingFace Trainer on Ray Train | 1x L4 GPU | [HuggingFace + Ray Train](https://docs.ray.io/en/latest/train/huggingface-accelerate.html) | Planned |
| 15 | jax-training | Distributed JAX model training on GPUs with Ray Train | 1x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/jax_training) | Planned |
| 16 | megatron-fine-tuning | LLM fine-tuning with Megatron-Bridge and Ray Train — multi-GPU FSDP | 4x L4 GPU | [Anyscale examples](https://github.com/anyscale/examples/tree/main/megatron_training) | Needs quota |

---

### 06 — Observability

| # | Tutorial | What It Demonstrates | Compute | Source | Status |
|---|----------|---------------------|---------|--------|--------|
| 17 | langsmith-tracing | Add LangSmith tracing to a LangChain/LangGraph app running on Ray | CPU | [LangSmith docs](https://docs.smith.langchain.com/) | Planned |
| 18 | ray-dashboard | Ray metrics, actor graphs, task timeline in the Anyscale console | CPU | Built-in | Planned |

---

## Compute Requirements Summary

| GPU Count | Tutorials | Action Needed |
|-----------|-----------|---------------|
| 0 (CPU) | 01, 02, 06, 10, 11, 12, 17, 18 | Works today |
| 1x L4 | 03, 04, 07, 13, 14, 15 | Works today (8 vCPU quota) |
| 2–4x L4 | 08, 09, 16 | Request quota increase first |

Request quota increase: AWS Console → Service Quotas → EC2 → `Running On-Demand G and VT instances`

---

## LLMs Covered

| Model | Size | Used In | Access |
|-------|------|---------|--------|
| Llama 3.1 8B Instruct | 8B | 03, 07, 10, 11, 14 | HF token (gated) or `unsloth/` mirror |
| Llama 3.1 70B Instruct | 70B | 08 | HF token + quota |
| Llama 3.1 8B (unsloth) | 8B | 03 | Public |

---

## Frameworks Covered

| Framework | Purpose | Tutorials |
|-----------|---------|-----------|
| Ray Core | Task/actor parallelism | 01, 02, all |
| Ray Data | Distributed batch processing | 03, 04, 05 |
| Ray Serve | Online inference APIs | 06, 07, 08, 09, 13 |
| Ray Train | Distributed training | 14, 15, 16 |
| RayDP | Spark on Ray | 02 |
| vLLM | LLM inference engine | 03, 07 |
| SGLang | High-throughput LLM serving | 09 |
| LangChain | LLM application framework | 10, 17 |
| LangGraph | Agent workflow orchestration | 11, 17 |
| LangSmith | LLM observability & tracing | 17 |
| AWS Strands | Agent SDK (AWS-native) | 12 |
| AWS AgentCore | Managed agent runtime | 13 |
| HuggingFace | Model hub + Trainer | 14 |
| JAX | ML framework (Google) | 15 |
| Apache Spark | Distributed SQL/ETL | 02 |

---

## Running Multiple Tutorials in One Cluster Session

CPU tutorials run sequentially without tearing down:

```bash
INSTALL_GPU_NODEPOOL=true ./cluster/create.sh
./anyscale/setup.sh

# CPU jobs (submit and wait)
./tutorials/job-hello-world/submit.sh
./tutorials/spark-on-ray/submit.sh
./tutorials/service-hello-world/deploy.sh

# GPU jobs (submit and wait — share the same g6.2xlarge)
./tutorials/llm-batch-inference/submit.sh
./tutorials/deploy-llama-3-8b/deploy.sh

./anyscale/teardown.sh
./cluster/destroy.sh
```

Services (Ray Serve) stay up until explicitly terminated — use `anyscale service terminate` before teardown.
