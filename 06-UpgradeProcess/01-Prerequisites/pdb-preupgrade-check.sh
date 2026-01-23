
#!/usr/bin/env bash
set -euo pipefail

REPORT="pdb-preupgrade-report.txt"
BLOCK=false

echo "==================================================" | tee "$REPORT"
echo "PDB PRE-UPGRADE CHECK" | tee -a "$REPORT"
echo "Generated On: $(date -u)" | tee -a "$REPORT"
echo "==================================================" | tee -a "$REPORT"
echo | tee -a "$REPORT"

log() { echo "$1" | tee -a "$REPORT"; }

log "[PDB Inventory]"
kubectl get pdb -A | tee -a "$REPORT"
echo | tee -a "$REPORT"

log "[Blocking PDBs]"
BLOCKING=$(kubectl get pdb -A -o json | jq -r '
.items[] | select(.status.disruptionsAllowed == 0) |
"\(.metadata.namespace) \(.metadata.name)"')

if [[ -n "$BLOCKING" ]]; then
  log "❌ Blocking PDBs found:"
  echo "$BLOCKING" | tee -a "$REPORT"
  BLOCK=true
else
  log "✅ No blocking PDBs found"
fi
echo | tee -a "$REPORT"

echo "==================================================" | tee -a "$REPORT"
if $BLOCK; then
  log "FINAL DECISION: ❌ NO-GO – FIX PDBs"
  exit 1
else
  log "FINAL DECISION: ✅ GO – PDBs OK"
  exit 0
fi
