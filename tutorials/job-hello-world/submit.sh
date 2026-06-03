#!/usr/bin/env bash
# submit.sh — Submit the hello world job to your Anyscale EKS cloud.
# Run from the repo root: ./tutorials/job-hello-world/submit.sh
#
# Source: https://github.com/anyscale/examples/tree/main/job_hello_world
#
# What this does:
#   Runs 100 Ray tasks in parallel — each takes a number and squares it.
#   A minimal proof that Anyscale can schedule and run Ray jobs on your EKS cluster.
#
# Prerequisites:
#   - EKS cluster running:    ./cluster/create.sh
#   - Anyscale connected:     ./anyscale/setup.sh
#   - Anyscale CLI logged in: anyscale login

set -euo pipefail

CLOUD="${ANYSCALE_CLOUD_NAME:-eks-ray-cloud}"
EXAMPLES_REPO="https://github.com/anyscale/examples/archive/refs/heads/main.zip"

echo "── Submitting hello world job ───────────────────────────────────────────"
printf "  Cloud : %s\n" "${CLOUD}"
echo ""

anyscale job submit \
    --cloud "${CLOUD}" \
    --working-dir "${EXAMPLES_REPO}" \
    --name "job-hello-world" \
    --env-vars "EXAMPLE_ENV_VAR=hello-from-eks" \
    -- python job_hello_world/main.py

echo ""
echo "Job submitted. Monitor at: https://console.anyscale.com/jobs"
