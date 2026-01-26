#!/usr/bin/env bash
set -euo pipefail

OLD_LABEL="nodegroup=workers-v1"
NEW_LABEL="nodegroup=workers-v2"

echo "[INFO] Waiting for new nodes to be Ready"

until kubectl get nodes -l "$NEW_LABEL" | grep -q Ready; do
  sleep 20
done

echo "[INFO] New worker nodes are Ready"

OLD_NODES=$(kubectl get nodes -l "$OLD_LABEL" -o name)

for NODE in $OLD_NODES; do
  echo "[ACTION] Cordoning $NODE"
  kubectl cordon "$NODE"

  echo "[ACTION] Draining $NODE"
  kubectl drain "$NODE" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=10m

  echo "[INFO] $NODE drained successfully"
done

