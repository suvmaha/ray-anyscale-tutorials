#!/usr/bin/env bash
# cleanup.sh — Remove Tutorial 1 resources from the cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deleting RayService weather-mcp..."
kubectl delete rayservice weather-mcp --ignore-not-found

if [[ -f "${SCRIPT_DIR}/ray-service.yaml" ]]; then
    rm "${SCRIPT_DIR}/ray-service.yaml"
    echo "Removed generated ray-service.yaml"
fi

echo "Tutorial 1 cleaned up."
