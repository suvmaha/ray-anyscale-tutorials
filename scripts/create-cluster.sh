#!/usr/bin/env bash
# create-cluster.sh — Deploy VPC with CDK, create EKS cluster with eksctl, install KubeRay.
# Run from the repo root: ./scripts/create-cluster.sh
#
# Steps:
#   1. CDK deploys VPC (2 AZs, 1 NAT gateway)
#   2. Read CDK outputs (VPC ID, subnet IDs)
#   3. envsubst fills cluster.yaml.template → cluster/cluster.yaml
#   4. eksctl creates EKS Auto Mode cluster
#   5. Install KubeRay operator via Helm
#   6. Verify

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
export KUBERAY_VERSION="${KUBERAY_VERSION:-1.2.2}"

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
printf "║  KubeRay        : %-50s║\n" "v${KUBERAY_VERSION} (Helm)"
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
echo "── STEP 5: Install KubeRay operator via Helm ───────────────────────────"
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ --force-update
helm repo update kuberay
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
    --version "${KUBERAY_VERSION}" \
    --namespace kuberay-system \
    --create-namespace \
    --wait

echo ""
echo "── STEP 6: Verify ──────────────────────────────────────────────────────"
kubectl get nodes
echo ""
kubectl -n kuberay-system get pods
echo ""
echo "EKS cluster ${EKS_CLUSTER_NAME} is ready."
echo ""
echo "Next steps:"
echo "  ./scripts/smoke-test.sh                       # verify KubeRay works"
echo "  ./tutorials/01-mcp-ray-serve/deploy.sh        # deploy Tutorial 1"
