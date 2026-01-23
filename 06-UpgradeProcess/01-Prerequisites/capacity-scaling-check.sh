#!/usr/bin/env bash
set -euo pipefail

REPORT="capacity-scaling-report.txt"
FAIL=false

echo "==================================================" | tee "$REPORT"
echo "CAPACITY & SCALING READINESS CHECK" | tee -a "$REPORT"
echo "Generated On: $(date -u)" | tee -a "$REPORT"
echo "==================================================" | tee -a "$REPORT"
echo | tee -a "$REPORT"

log() { echo "$1" | tee -a "$REPORT"; }

log "[1] Cluster Autoscaler"
if kubectl get deploy -n kube-system cluster-autoscaler &>/dev/null; then
  log "✅ Cluster Autoscaler detected"
else
  log "❌ Cluster Autoscaler NOT found"
  FAIL=true
fi
echo | tee -a "$REPORT"

log "[2] Node Utilization]"
kubectl top nodes | tee -a "$REPORT"
echo | tee -a "$REPORT"

log "[3] Dry-run node drain test]"
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
if kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --dry-run=server; then
  log "✅ Dry-run drain successful"
else
  log "❌ Dry-run drain failed"
  FAIL=true
fi
echo | tee -a "$REPORT"

log "[4] HPA Health]"
kubectl get hpa -A | tee -a "$REPORT"
if kubectl get pods -n kube-system | grep -q metrics-server; then
  log "✅ metrics-server running"
else
  log "❌ metrics-server missing"
  FAIL=true
fi
echo | tee -a "$REPORT"

echo "==================================================" | tee -a "$REPORT"
if $FAIL; then
  log "FINAL DECISION: ❌ NO-GO – CAPACITY NOT READY"
  exit 1
else
  log "FINAL DECISION: ✅ GO – CAPACITY READY"
  exit 0
fi
