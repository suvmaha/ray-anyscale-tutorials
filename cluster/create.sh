#!/usr/bin/env bash
# create.sh — Deploy VPC with CDK, create EKS cluster with eksctl.
# Run from the repo root: ./cluster/create.sh
#
# Steps:
#   1. CDK deploys VPC (2 AZs, 1 NAT gateway)
#   2. Read CDK outputs (VPC ID, subnet IDs)
#   3. envsubst fills cluster.yaml.template → cluster/cluster.yaml
#   4. eksctl creates EKS Auto Mode cluster
#   5. Associate IAM OIDC provider (required for IRSA)
#   6. Optionally apply GPU NodePool (g6/L4 — for LLM tutorials)
#   7. Verify
#
# Default:                       ./cluster/create.sh
# With GPU NodePool:             INSTALL_GPU_NODEPOOL=true ./cluster/create.sh
# KubeRay (run after cluster):  ./kuberay/install.sh

set -euo pipefail

_SCRIPT="${BASH_SOURCE[0]}"
case "${_SCRIPT}" in
    /*)  ;;
    */*) _SCRIPT="${PWD}/${_SCRIPT}" ;;
    *)   _SCRIPT="$(command -v "${_SCRIPT}")" ;;
esac
REPO_ROOT="$(cd "$(dirname "${_SCRIPT}")/.." && pwd)"
STACK_NAME="EksRayStack"

# ── Cluster parameters (override via env vars) ─────────────────────────────

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="eks-ray-platform"
export K8S_VERSION="${K8S_VERSION:-1.35}"
INSTALL_GPU_NODEPOOL="${INSTALL_GPU_NODEPOOL:-false}"

echo ""
echo "── STEP 1: Deploy VPC with CDK ─────────────────────────────────────────"
cd "${REPO_ROOT}/infra"
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate
pip install -q -r requirements.txt
cdk deploy --require-approval never
deactivate

echo ""
echo "── STEP 2: Read CDK outputs ────────────────────────────────────────────"

get_output() {
    aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${AWS_REGION}" \
        --query "Stacks[0].Outputs[?OutputKey=='${1}'].OutputValue" \
        --output text
}

export VPC_ID=$(get_output "VpcId")
PRIVATE_SUBNETS=$(get_output "PrivateSubnetIds")
PUBLIC_SUBNETS=$(get_output "PublicSubnetIds")

export PRIVATE_SUBNET_1=$(echo "${PRIVATE_SUBNETS}" | cut -d',' -f1)
export PRIVATE_SUBNET_2=$(echo "${PRIVATE_SUBNETS}" | cut -d',' -f2)
export PUBLIC_SUBNET_1=$(echo "${PUBLIC_SUBNETS}" | cut -d',' -f1)
export PUBLIC_SUBNET_2=$(echo "${PUBLIC_SUBNETS}" | cut -d',' -f2)

export AZ_1=$(aws ec2 describe-subnets --subnet-ids "${PRIVATE_SUBNET_1}" --region "${AWS_REGION}" \
    --query "Subnets[0].AvailabilityZone" --output text)
export AZ_2=$(aws ec2 describe-subnets --subnet-ids "${PRIVATE_SUBNET_2}" --region "${AWS_REGION}" \
    --query "Subnets[0].AvailabilityZone" --output text)

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║            EKS Ray Platform — Architecture Summary                  ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster name   : %-50s║\n" "${EKS_CLUSTER_NAME}"
printf "║  AWS account    : %-50s║\n" "${AWS_ACCOUNT_ID}"
printf "║  Region         : %-50s║\n" "${AWS_REGION}"
printf "║  Kubernetes     : %-50s║\n" "${K8S_VERSION}"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  VPC            : %-50s║\n" "${VPC_ID}"
printf "║  Private subnet : %-50s║\n" "${PRIVATE_SUBNET_1} (${AZ_1})"
printf "║  Private subnet : %-50s║\n" "${PRIVATE_SUBNET_2} (${AZ_2})"
printf "║  Public subnet  : %-50s║\n" "${PUBLIC_SUBNET_1} (${AZ_1})"
printf "║  Public subnet  : %-50s║\n" "${PUBLIC_SUBNET_2} (${AZ_2})"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Node mode      : %-50s║\n" "EKS Auto Mode (Karpenter)"
printf "║  GPU NodePool   : %-50s║\n" "${INSTALL_GPU_NODEPOOL} (set INSTALL_GPU_NODEPOOL=true for LLM jobs)"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed with cluster creation? (y/n): " confirm
if [[ "${confirm}" != "y" ]]; then
    echo "Aborted. VPC remains deployed."
    echo "Run 'cdk destroy' in infra/ to remove it."
    exit 0
fi

echo ""
echo "── STEP 3: Generate eksctl cluster config ──────────────────────────────"
envsubst < "${REPO_ROOT}/cluster/cluster.yaml.template" > "${REPO_ROOT}/cluster/cluster.yaml"
echo "Written: cluster/cluster.yaml"

echo ""
echo "── STEP 4: Create EKS cluster with eksctl ──────────────────────────────"
eksctl create cluster -f "${REPO_ROOT}/cluster/cluster.yaml"

echo ""
echo "── STEP 5: Associate IAM OIDC provider ─────────────────────────────────"
eksctl utils associate-iam-oidc-provider \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --approve
echo "OIDC provider associated — IRSA enabled for this cluster."

echo ""
echo "── STEP 7: Apply GPU NodePool (optional) ───────────────────────────────"
if [[ "${INSTALL_GPU_NODEPOOL}" == "true" ]]; then
    kubectl apply -f "${REPO_ROOT}/cluster/gpu-nodepool.yaml"
    echo "GPU NodePool (g6/L4) applied — Karpenter will provision nodes on demand."
else
    echo "Skipped (INSTALL_GPU_NODEPOOL=false)."
    echo "For Anyscale LLM tutorials: INSTALL_GPU_NODEPOOL=true ./cluster/create.sh"
fi

echo ""
echo "── STEP 8: Verify ──────────────────────────────────────────────────────"
kubectl get nodes
echo ""
echo "EKS cluster ${EKS_CLUSTER_NAME} is ready."
echo ""
echo "Next steps:"
echo "  ./anyscale/setup.sh     # wire Anyscale to this cluster"
echo "  ./kuberay/install.sh    # install KubeRay operator (if needed)"
