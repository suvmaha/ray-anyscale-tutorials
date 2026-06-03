#!/usr/bin/env bash
# teardown.sh — Remove Anyscale from the EKS cluster.
# Run from the repo root: ./anyscale/teardown.sh
# Run this BEFORE ./cluster/destroy.sh

set -euo pipefail

export AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="eks-ray-platform"
export ANYSCALE_CLOUD_NAME="${ANYSCALE_CLOUD_NAME:-eks-ray-cloud}"
ANYSCALE_NAMESPACE="${ANYSCALE_NAMESPACE:-anyscale-operator}"

echo "── STEP 1: Delete Anyscale cloud registration ──────────────────────────"
anyscale cloud delete --name "${ANYSCALE_CLOUD_NAME}" --yes 2>/dev/null \
    && echo "  Cloud deleted: ${ANYSCALE_CLOUD_NAME}" \
    || echo "  Cloud not found — skipping."

echo ""
echo "── STEP 2: Uninstall Anyscale operator ─────────────────────────────────"
RELEASE=$(helm list -n "${ANYSCALE_NAMESPACE}" -q 2>/dev/null | head -1 || echo "")
if [[ -n "${RELEASE}" ]]; then
    helm uninstall "${RELEASE}" -n "${ANYSCALE_NAMESPACE}"
    kubectl delete namespace "${ANYSCALE_NAMESPACE}" --ignore-not-found
    echo "  Anyscale operator uninstalled."
else
    echo "  Anyscale operator not found — skipping."
fi

echo ""
echo "── STEP 3: Delete Anyscale CloudFormation stack ────────────────────────"
# anyscale cloud setup creates a stack — find it by tag
CF_STACK=$(aws cloudformation describe-stacks \
    --region "${AWS_REGION}" \
    --query "Stacks[?Tags[?Key=='anyscale-cluster-name'&&Value=='${EKS_CLUSTER_NAME}']].StackName" \
    --output text 2>/dev/null || echo "")

if [[ -z "${CF_STACK}" ]]; then
    echo "  No Anyscale CloudFormation stack found — skipping."
else
    echo "  Deleting stack: ${CF_STACK}"
    aws cloudformation delete-stack --stack-name "${CF_STACK}" --region "${AWS_REGION}"
    aws cloudformation wait stack-delete-complete --stack-name "${CF_STACK}" --region "${AWS_REGION}"
    echo "  CloudFormation stack deleted."
fi

echo ""
echo "Anyscale teardown complete."
echo "Now run: ./cluster/destroy.sh"
