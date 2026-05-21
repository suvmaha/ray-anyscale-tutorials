#!/usr/bin/env bash
# submit.sh — Submit LLM batch inference job to Anyscale.
# Run from the repo root: ./tutorials/llm-batch-inference/submit.sh
#
# Prerequisites:
#   - Cluster created with GPU NodePool:  INSTALL_GPU_NODEPOOL=true ./cluster/create.sh
#   - Anyscale wired to the cluster:      ./anyscale/setup.sh

set -euo pipefail

ANYSCALE_CLOUD_NAME="${ANYSCALE_CLOUD_NAME:-eks-ray-cloud}"
TUTORIAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Submitting LLM batch inference job to cloud: ${ANYSCALE_CLOUD_NAME}"
echo ""

anyscale job submit \
    --cloud "${ANYSCALE_CLOUD_NAME}" \
    --working-dir "${TUTORIAL_DIR}" \
    --config-file "${TUTORIAL_DIR}/job.yaml"

echo ""
echo "Monitor job:"
echo "  anyscale job status --name llm-batch-inference"
echo "  anyscale job logs --name llm-batch-inference"
echo "  https://console.anyscale.com"
