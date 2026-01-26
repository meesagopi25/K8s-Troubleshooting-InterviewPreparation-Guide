#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Input arguments
# -------------------------------
CLUSTER_NAME="$1"
NODEGROUP_NAME="$2"
TARGET_VERSION="$3"
REGION="$4"

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <cluster-name> <nodegroup-name> <target-k8s-version> <region>"
  exit 1
fi

echo "=============================================="
echo "EKS MANAGED NODE GROUP UPGRADE"
echo "Cluster        : $CLUSTER_NAME"
echo "Node Group     : $NODEGROUP_NAME"
echo "Target Version : $TARGET_VERSION"
echo "Region         : $REGION"
echo "=============================================="

# -------------------------------
# Pre-checks
# -------------------------------
echo "[Pre-check] Verifying cluster access"
kubectl get nodes >/dev/null

echo "[Pre-check] Checking PDBs"
kubectl get pdb -A

echo "[Pre-check] Current node versions"
kubectl get nodes -o wide

# -------------------------------
# Trigger rolling upgrade
# -------------------------------
echo "[Action] Triggering managed node group upgrade"

aws eks update-nodegroup-version \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --kubernetes-version "$TARGET_VERSION" \
  --region "$REGION"

echo "[Info] Upgrade request submitted"

# -------------------------------
# Monitor upgrade
# -------------------------------
echo "[Monitor] Waiting for node group to become ACTIVE"

while true; do
  STATUS=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --region "$REGION" \
    --query 'nodegroup.status' \
    --output text)

  echo "Node group status: $STATUS"

  if [[ "$STATUS" == "ACTIVE" ]]; then
    break
  fi

  if [[ "$STATUS" == "FAILED" ]]; then
    echo "ERROR: Node group upgrade failed"
    exit 1
  fi

  sleep 30
done

# -------------------------------
# Post-validation
# -------------------------------
echo "[Post-check] Verifying nodes after upgrade"
kubectl get nodes -o wide

echo "[Post-check] Verifying pod health"
kubectl get pods -A | grep -v Running || true

echo "=============================================="
echo "Managed node group upgrade completed successfully"
echo "=============================================="

