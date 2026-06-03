#!/usr/bin/env bash
# teardown.sh — Remove Anyscale from the EKS cluster.
# Run from the repo root: ./anyscale/teardown.sh
# Run this BEFORE ./cluster/destroy.sh

set -euo pipefail

export AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="eks-ray-platform"
export ANYSCALE_CLOUD_NAME="${ANYSCALE_CLOUD_NAME:-eks-ray-cloud}"
ANYSCALE_NAMESPACE="${ANYSCALE_NAMESPACE:-anyscale-operator}"

TEARDOWN_START=$(date +%s)
TEARDOWN_START_LABEL=$(date '+%H:%M:%S')

echo "── STEP 1: Delete Anyscale cloud registration ──────────────────────────"
if anyscale cloud list 2>/dev/null | grep -q "${ANYSCALE_CLOUD_NAME}"; then
    anyscale cloud delete --name "${ANYSCALE_CLOUD_NAME}" --yes
    echo "  Cloud deleted: ${ANYSCALE_CLOUD_NAME}"
else
    echo "  Cloud not found — skipping."
fi

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
# anyscale cloud setup creates a stack named k8s-<cloud-name>-<id>.
# Search by name prefix first, fall back to tag search.
CF_STACK=$(aws cloudformation list-stacks \
    --region "${AWS_REGION}" \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[?starts_with(StackName,'k8s-${ANYSCALE_CLOUD_NAME}-')].StackName" \
    --output text 2>/dev/null || echo "")

if [[ -z "${CF_STACK}" ]]; then
    CF_STACK=$(aws cloudformation describe-stacks \
        --region "${AWS_REGION}" \
        --query "Stacks[?Tags[?Key=='anyscale-cluster-name'&&Value=='${EKS_CLUSTER_NAME}']].StackName" \
        --output text 2>/dev/null || echo "")
fi

if [[ -z "${CF_STACK}" ]]; then
    echo "  No Anyscale CloudFormation stack found — skipping."
else
    echo "  Found stack: ${CF_STACK}"

    # Empty the versioned S3 bucket before deletion — CloudFormation cannot delete
    # a non-empty versioned bucket and will leave the stack in DELETE_FAILED.
    BUCKET=$(aws cloudformation list-stack-resources \
        --stack-name "${CF_STACK}" --region "${AWS_REGION}" \
        --query "StackResourceSummaries[?ResourceType=='AWS::S3::Bucket'].PhysicalResourceId" \
        --output text 2>/dev/null || echo "")
    if [[ -n "${BUCKET}" ]]; then
        echo "  Emptying versioned S3 bucket: ${BUCKET}"
        VERSIONS_JSON=$(aws s3api list-object-versions --bucket "${BUCKET}" \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}, Quiet: true}' \
            --output json 2>/dev/null || echo '{"Objects":null,"Quiet":true}')
        if echo "${VERSIONS_JSON}" | grep -q '"Key"'; then
            aws s3api delete-objects --bucket "${BUCKET}" --delete "${VERSIONS_JSON}" >/dev/null
        fi
        MARKERS_JSON=$(aws s3api list-object-versions --bucket "${BUCKET}" \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}, Quiet: true}' \
            --output json 2>/dev/null || echo '{"Objects":null,"Quiet":true}')
        if echo "${MARKERS_JSON}" | grep -q '"Key"'; then
            aws s3api delete-objects --bucket "${BUCKET}" --delete "${MARKERS_JSON}" >/dev/null
        fi
        echo "  S3 bucket emptied."
    fi

    echo "  Deleting stack: ${CF_STACK}"
    aws cloudformation delete-stack --stack-name "${CF_STACK}" --region "${AWS_REGION}"
    aws cloudformation wait stack-delete-complete --stack-name "${CF_STACK}" --region "${AWS_REGION}"
    echo "  CloudFormation stack deleted."
fi

TEARDOWN_END=$(date +%s)
TEARDOWN_ELAPSED=$(( TEARDOWN_END - TEARDOWN_START ))
TEARDOWN_MIN=$(( TEARDOWN_ELAPSED / 60 ))
TEARDOWN_SEC=$(( TEARDOWN_ELAPSED % 60 ))

echo ""
echo "Anyscale teardown complete."
echo ""
echo "⏱  Started : ${TEARDOWN_START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${TEARDOWN_MIN}m ${TEARDOWN_SEC}s"
echo ""
echo "Now run: ./cluster/destroy.sh"
