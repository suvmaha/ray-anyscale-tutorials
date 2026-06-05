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
echo "── STEP 3: Delete Anyscale CloudFormation stack(s) ────────────────────"
# anyscale cloud setup creates a stack named k8s-<cloud-name>-<id>.
# Multiple stacks can accumulate from failed setup attempts — delete all.
CF_STACKS=$(aws cloudformation list-stacks \
    --region "${AWS_REGION}" \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE DELETE_FAILED \
    --query "StackSummaries[?starts_with(StackName,'k8s-${ANYSCALE_CLOUD_NAME}-')].StackName" \
    --output text 2>/dev/null || echo "")

if [[ -z "${CF_STACKS}" ]]; then
    CF_STACKS=$(aws cloudformation describe-stacks \
        --region "${AWS_REGION}" \
        --query "Stacks[?Tags[?Key=='anyscale-cluster-name'&&Value=='${EKS_CLUSTER_NAME}']].StackName" \
        --output text 2>/dev/null || echo "")
fi

if [[ -z "${CF_STACKS}" ]]; then
    echo "  No Anyscale CloudFormation stacks found — skipping."
else
    for CF_STACK in ${CF_STACKS}; do
        echo "  Found stack: ${CF_STACK}"

        # Empty the versioned S3 bucket before deletion — CloudFormation cannot
        # delete a non-empty versioned bucket and will leave the stack DELETE_FAILED.
        BUCKET=$(aws cloudformation list-stack-resources \
            --stack-name "${CF_STACK}" --region "${AWS_REGION}" \
            --query "StackResourceSummaries[?ResourceType=='AWS::S3::Bucket'].PhysicalResourceId" \
            --output text 2>/dev/null || echo "")
        if [[ -n "${BUCKET}" ]]; then
            echo "  Emptying versioned S3 bucket: ${BUCKET}"
            # Write versions to a temp file — avoids MalformedXML from inline shell JSON
            # interpolation. Uses file:// so CF can still delete the (now-empty) bucket.
            TMPFILE=$(mktemp /tmp/s3-delete.XXXXXX.json)
            for QUERY in 'Versions[].{Key:Key,VersionId:VersionId}' 'DeleteMarkers[].{Key:Key,VersionId:VersionId}'; do
                aws s3api list-object-versions --bucket "${BUCKET}" \
                    --query "${QUERY}" --output json 2>/dev/null > "${TMPFILE}" || true
                CONTENT=$(cat "${TMPFILE}")
                if [[ "${CONTENT}" != "null" && "${CONTENT}" != "[]" && -n "${CONTENT}" ]]; then
                    echo "{\"Objects\":${CONTENT},\"Quiet\":true}" > "${TMPFILE}"
                    aws s3api delete-objects --bucket "${BUCKET}" \
                        --delete "file://${TMPFILE}" >/dev/null
                fi
            done
            rm -f "${TMPFILE}"
            echo "  S3 bucket emptied."
        fi

        # If the stack is already in DELETE_FAILED, collect resources that previously
        # failed so we can skip them on retry (they'll need manual cleanup).
        STACK_STATUS=$(aws cloudformation describe-stacks \
            --stack-name "${CF_STACK}" --region "${AWS_REGION}" \
            --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "")
        RETAIN_ARGS=""
        if [[ "${STACK_STATUS}" == "DELETE_FAILED" ]]; then
            FAILED_RESOURCES=$(aws cloudformation describe-stack-events \
                --stack-name "${CF_STACK}" --region "${AWS_REGION}" \
                --query "StackEvents[?ResourceStatus=='DELETE_FAILED'].LogicalResourceId" \
                --output text 2>/dev/null || echo "")
            if [[ -n "${FAILED_RESOURCES}" ]]; then
                echo "  Retrying DELETE_FAILED stack — skipping: ${FAILED_RESOURCES}"
                RETAIN_ARGS="--retain-resources ${FAILED_RESOURCES}"
            fi
        fi

        echo "  Deleting stack: ${CF_STACK}"
        # shellcheck disable=SC2086
        aws cloudformation delete-stack --stack-name "${CF_STACK}" --region "${AWS_REGION}" ${RETAIN_ARGS}
        aws cloudformation wait stack-delete-complete --stack-name "${CF_STACK}" --region "${AWS_REGION}"
        echo "  CloudFormation stack deleted: ${CF_STACK}"
    done
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
