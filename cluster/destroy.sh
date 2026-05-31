#!/usr/bin/env bash
# destroy.sh — Tear down EKS cluster and VPC.
# Run from the repo root: ./cluster/destroy.sh
#
# Prerequisites:
#   - If using Anyscale: run ./anyscale/teardown.sh first
#   - If using KubeRay: run ./kuberay/uninstall.sh first
#
# Order:
#   1. Delete EKS cluster (eksctl)
#   2. Destroy CDK stack (VPC)
#   3. Optionally delete ray-* ECR repositories

set -euo pipefail

CLUSTER_NAME="eks-ray-platform"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK_NAME="EksRayStack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "── STEP 1: Delete EKS cluster with eksctl ──────────────────────────────"
CLUSTER_STATUS=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
    --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "${CLUSTER_STATUS}" == "NOT_FOUND" ]]; then
    echo "EKS cluster not found — skipping."
else
    eksctl delete cluster --name "${CLUSTER_NAME}" --region "${REGION}" --wait
fi

echo ""
echo "── STEP 2: Destroy CDK stack (VPC) ─────────────────────────────────────"
cd "${REPO_ROOT}/infra"
source .venv/bin/activate
cdk destroy --force
deactivate

echo ""
echo "── STEP 3: ECR repositories ────────────────────────────────────────────"
REPOS=$(aws ecr describe-repositories --region "${REGION}" \
    --query "repositories[?starts_with(repositoryName,'ray-')].repositoryName" \
    --output text 2>/dev/null || echo "")
if [[ -z "${REPOS}" ]]; then
    echo "No ray-* ECR repositories found."
else
    echo "Found ray-* ECR repositories:"
    for repo in ${REPOS}; do echo "  ${repo}"; done
    echo ""
    read -r -p "Delete these ECR repositories? (y/N): " delete_ecr
    if [[ "${delete_ecr}" == "y" || "${delete_ecr}" == "Y" ]]; then
        for repo in ${REPOS}; do
            aws ecr delete-repository --repository-name "${repo}" --region "${REGION}" --force
            echo "  Deleted: ${repo}"
        done
    else
        echo "ECR repositories kept."
    fi
fi

echo ""
echo "── Final check ─────────────────────────────────────────────────────────"
CLUSTER_STATUS=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
    --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
CDK_STACK=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
    --region "${REGION}" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")
EKSCTL_STACK=$(aws cloudformation describe-stacks \
    --stack-name "eksctl-${CLUSTER_NAME}-cluster" \
    --region "${REGION}" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")

[[ "${CLUSTER_STATUS}" == "NOT_FOUND" ]] && echo "  ✅  EKS cluster deleted" || echo "  ❌  EKS cluster still exists (${CLUSTER_STATUS})"
[[ "${EKSCTL_STACK}" == "NOT_FOUND" ]] && echo "  ✅  eksctl CloudFormation stack deleted" || echo "  ❌  eksctl stack still exists (${EKSCTL_STACK})"
[[ "${CDK_STACK}" == "NOT_FOUND" ]] && echo "  ✅  CDK VPC stack deleted" || echo "  ❌  CDK stack still exists (${CDK_STACK})"
echo ""
