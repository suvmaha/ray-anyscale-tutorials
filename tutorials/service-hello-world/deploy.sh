#!/usr/bin/env bash
# deploy.sh — Deploy the hello-world Ray Serve service to Anyscale.
# Run from the repo root: ./tutorials/service-hello-world/deploy.sh

set -euo pipefail

ANYSCALE_CLOUD_NAME="${ANYSCALE_CLOUD_NAME:-eks-ray-cloud}"
TUTORIAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="service-hello-world"

echo "Deploying ${SERVICE_NAME} to cloud: ${ANYSCALE_CLOUD_NAME}"
echo ""

anyscale service deploy -f "${TUTORIAL_DIR}/service.yaml"

echo ""
echo "Service deployed. Check status:"
echo "  anyscale service list"
echo "  anyscale service status --name ${SERVICE_NAME}"
echo ""
echo "Query the service (get token + URL from the deploy output above):"
echo "  python ${TUTORIAL_DIR}/query.py --token <TOKEN> --url <BASE_URL>"
echo ""
echo "Monitor: https://console.anyscale.com/services"
echo ""
echo "Terminate when done:"
echo "  anyscale service terminate --name ${SERVICE_NAME}"
