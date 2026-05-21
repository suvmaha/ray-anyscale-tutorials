#!/usr/bin/env bash
# smoke-test.sh — Verify EKS + KubeRay are working.
# Creates a minimal RayCluster, waits for the head pod, then deletes it.
# Run from the repo root: ./scripts/smoke-test.sh

set -euo pipefail

echo "── Cluster nodes ───────────────────────────────────────────────────────"
kubectl get nodes
echo ""

echo "── KubeRay operator ────────────────────────────────────────────────────"
kubectl -n kuberay-system get pods
echo ""

echo "── Creating smoke-test RayCluster ──────────────────────────────────────"
kubectl apply -f - <<'EOF'
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: smoke-test
spec:
  rayVersion: "2.44.0"
  headGroupSpec:
    rayStartParams:
      dashboard-host: "0.0.0.0"
      num-cpus: "0"
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray:2.44.0
          resources:
            limits:
              cpu: "1"
              memory: "2Gi"
            requests:
              cpu: "500m"
              memory: "1Gi"
EOF

echo "Waiting for smoke-test head pod (timeout: 5m)..."
kubectl wait pod \
    --selector=ray.io/cluster=smoke-test,ray.io/node-type=head \
    --for=condition=Ready \
    --timeout=300s

echo ""
echo "── RayCluster is ready ─────────────────────────────────────────────────"
kubectl get raycluster smoke-test
kubectl get pods -l ray.io/cluster=smoke-test
echo ""

echo "── Cleaning up smoke-test ──────────────────────────────────────────────"
kubectl delete raycluster smoke-test

echo ""
echo "Smoke test passed. KubeRay is working correctly."
