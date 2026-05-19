#!/usr/bin/env bash
# deploy.sh — Build + push ECR image, then apply the RayService to EKS.
# Run from the repo root: ./tutorials/01-mcp-ray-serve/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export ECR_REPO="ray-weather-mcp"
export ECR_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest"

echo "── Step 1: Authenticate to ECR ─────────────────────────────────────────"
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "── Step 2: Create ECR repository (idempotent) ──────────────────────────"
aws ecr describe-repositories \
    --repository-names "${ECR_REPO}" \
    --region "${AWS_REGION}" 2>/dev/null || \
aws ecr create-repository \
    --repository-name "${ECR_REPO}" \
    --region "${AWS_REGION}"

echo "── Step 3: Build and push Docker image ─────────────────────────────────"
docker build --platform linux/amd64 -t "${ECR_IMAGE}" "${SCRIPT_DIR}"
docker push "${ECR_IMAGE}"

echo "── Step 4: Generate RayService manifest ────────────────────────────────"
envsubst < "${SCRIPT_DIR}/ray-service.yaml.template" > "${SCRIPT_DIR}/ray-service.yaml"
echo "Written: tutorials/01-mcp-ray-serve/ray-service.yaml"

echo "── Step 5: Apply to cluster ────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/ray-service.yaml"

echo "── Step 6: Wait for RayService pods ────────────────────────────────────"
echo "Waiting up to 5 minutes for head pod to be Ready..."
kubectl wait pod \
    --selector=ray.io/cluster \
    --for=condition=Ready \
    --timeout=300s 2>/dev/null || \
    echo "  (pods still initializing — check 'kubectl get rayservice weather-mcp')"

echo "── Step 7: Service endpoint ────────────────────────────────────────────"
sleep 15
LB_HOSTNAME=$(kubectl get svc weather-mcp-serve-svc \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo ""
echo "RayService deployed!"
echo "  kubectl get rayservice weather-mcp -w"
if [[ "${LB_HOSTNAME}" != "pending" && -n "${LB_HOSTNAME}" ]]; then
    echo ""
    echo "  Health : http://${LB_HOSTNAME}/health"
    echo "  MCP    : http://${LB_HOSTNAME}/mcp"
    echo ""
    echo "Load test:"
    echo "  python3 ${SCRIPT_DIR}/load_test.py --url http://${LB_HOSTNAME}"
    echo "  python3 ${SCRIPT_DIR}/load_test.py --url http://${LB_HOSTNAME} --mcp --concurrency 20"
else
    echo ""
    echo "LoadBalancer is still provisioning (NLB takes ~2 min)."
    echo "  kubectl get svc weather-mcp-serve-svc -w"
fi
