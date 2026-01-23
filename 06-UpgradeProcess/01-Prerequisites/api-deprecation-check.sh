#!/usr/bin/env bash
set -euo pipefail

REPORT="api-deprecation-report.txt"
FAIL=false

echo "==================================================" | tee "$REPORT"
echo "API DEPRECATION & REMOVAL CHECK" | tee -a "$REPORT"
echo "Generated On: $(date -u)" | tee -a "$REPORT"
echo "==================================================" | tee -a "$REPORT"
echo | tee -a "$REPORT"

log() { echo "$1" | tee -a "$REPORT"; }

log "[1] Deprecated API usage via metrics"
METRICS=$(kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis || true)

if echo "$METRICS" | grep -v 'removed_release=""' | grep -q version; then
  log "❌ Deprecated API usage detected"
  echo "$METRICS" | tee -a "$REPORT"
  FAIL=true
else
  log "✅ No deprecated API usage detected"
fi
echo | tee -a "$REPORT"

log "[2] kubent scan"
kubent | tee -a "$REPORT" || FAIL=true
echo | tee -a "$REPORT"

log "[3] pluto scan (CRDs & cluster objects)"
pluto detect-all-in-cluster --target-versions k8s=v1.34 | tee -a "$REPORT" || FAIL=true
echo | tee -a "$REPORT"

echo "==================================================" | tee -a "$REPORT"
if $FAIL; then
  log "FINAL DECISION: ❌ NO-GO – API ISSUES FOUND"
  exit 1
else
  log "FINAL DECISION: ✅ GO – API CLEAN"
  exit 0
fi
