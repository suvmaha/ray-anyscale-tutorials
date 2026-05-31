#!/usr/bin/env bash
# install.sh — Install the KubeRay operator on the EKS cluster.
# Run from the repo root: ./kuberay/install.sh
#
# Prerequisites:
#   - EKS cluster is running: ./cluster/create.sh
#   - kubectl is configured

set -euo pipefail

KUBERAY_VERSION="${KUBERAY_VERSION:-1.2.2}"

echo "── Installing KubeRay operator v${KUBERAY_VERSION} ─────────────────────"
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ --force-update
helm repo update kuberay
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
    --version "${KUBERAY_VERSION}" \
    --namespace kuberay-system \
    --create-namespace \
    --wait

echo ""
echo "KubeRay v${KUBERAY_VERSION} installed."
echo ""
echo "Next: ./kuberay/smoke-test.sh"
