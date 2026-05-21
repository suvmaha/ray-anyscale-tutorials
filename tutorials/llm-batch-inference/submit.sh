#!/usr/bin/env bash
# submit.sh — Submit LLM batch inference job to Anyscale.
# Run from the repo root: ./tutorials/llm-batch-inference/submit.sh
#
# Prerequisites:
#   - Anyscale is set up on EKS: ./anyscale/setup.sh
#   - Cloud name matches ANYSCALE_CLOUD_NAME

set -euo pipefail

ANYSCALE_CLOUD_NAME="${ANYSCALE_CLOUD_NAME:-eks-ray-cloud}"

echo "Submitting LLM batch inference job to cloud: ${ANYSCALE_CLOUD_NAME}"
echo ""

anyscale job submit \
    --cloud "${ANYSCALE_CLOUD_NAME}" \
    --name "llm-batch-inference" \
    --working-dir https://github.com/anyscale/docs_examples/archive/refs/heads/main.zip \
    -- python llm_batch_inference/main.py

echo ""
echo "Monitor job:"
echo "  anyscale job list --cloud ${ANYSCALE_CLOUD_NAME}"
echo "  https://console.anyscale.com"
