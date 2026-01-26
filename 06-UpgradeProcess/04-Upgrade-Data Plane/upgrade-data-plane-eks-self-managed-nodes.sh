#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Input arguments
# -------------------------------
OLD_NODE_LABEL="$1"        # e.g. nodegroup=workers-v1
NEW_NODE_LABEL="$2"        # e.g. nodegroup=workers-v2
CLUSTER_NAME="$3"
REGION="$4"

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <old-node-label> <new-node-label> <cluster-name> <region>"
  exit 1
fi

echo "================================================="
echo "SELF-MANAGED NODE GROUP UPGRADE (ASG + DRAIN)"
echo "Cluster        : $CLUSTER_NAME"
echo "Old Nodes      : $OLD_NODE_LABEL"
echo "New Nodes      : $NEW_NODE_LABEL"
echo "Region         : $REGION"
echo "================================================="

# -------------------------------
# Pre-checks
# -------------------------------
echo "[Pre-check] Verifying cluster access"
kubectl get nodes >/dev/null

echo "[Pre-check] Verifying PodDisruptionBudgets"
kubectl get pdb -A

echo "[Pre-check] Current node inventory"
kubectl get nodes --show-labels

# -------------------------------
# Wait for new nodes
# -------------------------------
echo "[Wait] Waiting for new ASG nodes to be Ready"

until kubectl get nodes -l "$NEW_NODE_LABEL" | grep -q Ready; do
  echo "Waiting for new nodes..."
  sleep 30
done

echo "[Info] New worker nodes are Ready"

# -------------------------------
# Drain old nodes (one-by-one)
# -------------------------------
OLD_NODES=$(kubectl get nodes -l "$OLD_NODE_LABEL" -o name)

for NODE in $OLD_NODES; do
  echo "-----------------------------------------------"
  echo "[Action] Cordon node: $NODE"
  kubectl cordon "$NODE"

  echo "[Action] Drain node: $NODE"
  kubectl drain "$NODE" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=10m

  echo "[Info] Node drained successfully: $NODE"
done

# -------------------------------
# Post-validation
# -------------------------------
echo "[Post-check] Verifying cluster state"
kubectl get nodes
kubectl get pods -A | grep -v Running || true

echo "================================================="
echo "Self-managed worker upgrade completed successfully"
echo "================================================="
