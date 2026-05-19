#!/usr/bin/env bash
# destroy-cluster.sh — Tear down all resources in reverse creation order.
# Run from the repo root: ./scripts/destroy-cluster.sh
#
# Order:
#   1. Delete all RayService / RayCluster / RayJob resources
#   2. Uninstall KubeRay Helm release
#   3. Delete EKS cluster (eksctl)
#   4. Destroy CDK stack (VPC)
#   5. Optionally delete ray-* ECR repositories

set -euo pipefail

CLUSTER_NAME="eks-ray-platform"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK_NAME="EksRayStack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "── STEP 1: Delete Ray workloads ────────────────────────────────────────"
if kubectl cluster-info 2>/dev/null | grep -q "Kubernetes"; then
    kubectl delete rayservice --all --all-namespaces --ignore-not-found 2>/dev/null || true
    kubectl delete raycluster --all --all-namespaces --ignore-not-found 2>/dev/null || true
    kubectl delete rayjob --all --all-namespaces --ignore-not-found 2>/dev/null || true
    echo "Ray workloads deleted."
else
    echo "Cluster not reachable — skipping Ray workload deletion."
fi

echo ""
echo "── STEP 2: Uninstall KubeRay ───────────────────────────────────────────"
if helm status kuberay-operator -n kuberay-system 2>/dev/null | grep -q "deployed"; then
    helm uninstall kuberay-operator -n kuberay-system
    kubectl delete namespace kuberay-system --ignore-not-found
    echo "KubeRay uninstalled."
else
    echo "KubeRay not found — skipping."
fi

echo ""
echo "── STEP 3: Delete EKS cluster with eksctl ──────────────────────────────"
CLUSTER_STATUS=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
    --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "${CLUSTER_STATUS}" == "NOT_FOUND" ]]; then
    echo "EKS cluster not found — skipping."
else
    eksctl delete cluster --name "${CLUSTER_NAME}" --region "${REGION}" --wait
fi

echo ""
echo "── STEP 4: Destroy CDK stack (VPC) ─────────────────────────────────────"
cd "${REPO_ROOT}/infra"
source .venv/bin/activate
cdk destroy --force
deactivate

echo ""
echo "── STEP 5: ECR repositories ────────────────────────────────────────────"
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
