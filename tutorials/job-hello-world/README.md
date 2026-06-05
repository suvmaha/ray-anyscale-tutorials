# Hello World Job

Your first Ray job running on Anyscale + EKS. Submits 100 parallel tasks — each squares a number — as proof that Anyscale can schedule and run Ray workloads on your EKS cluster.

**Source:** [anyscale/examples — job_hello_world](https://github.com/anyscale/examples/tree/main/job_hello_world)

## What It Does

```python
@ray.remote
def f(i):
    return i ** 2

results = ray.get([f.remote(i) for i in range(100)])
```

100 tasks distributed across Ray workers on your EKS cluster. Without Ray — a sequential loop. With Ray — all 100 run in parallel.

## Prerequisites

- EKS cluster running — `./cluster/create.sh`
- Anyscale connected — `./anyscale/setup.sh`
- Anyscale CLI logged in — `anyscale login`

## Run

```bash
./tutorials/job-hello-world/submit.sh
```

Monitor the job at **console.anyscale.com/jobs**.

## How It Works

There is no local `main.py` in this folder — intentionally. The `submit.sh` script passes the Anyscale examples GitHub repo as `--working-dir`. Anyscale downloads it, and the job runs `job_hello_world/main.py` from inside that zip. No code to maintain locally — we reference the source directly.

## Expected Output

Anyscale pulls the working directory from the GitHub zip, schedules the job on your EKS cluster, and Ray distributes the 100 tasks across workers. Results appear in the job logs in the console.

## What's Next

- **LLM Batch Inference** — LLM batch inference at scale with Ray Data
