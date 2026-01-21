Below is a **production-ready, end-to-end automation bundle** covering **Runbook steps 4.1 → 4.4**, plus **one Jenkins pipeline** that executes them **in order with hard GO/NO-GO gates**.

This is designed for **Amazon EKS** and matches everything you have already validated manually.

---

# Overview – What You Will Get

### Scripts (Drop-in Ready)

| Step    | Script                      | Purpose                                   |
| ------- | --------------------------- | ----------------------------------------- |
| **4.1** | `eks-preupgrade-check.sh`   | Add-on & version compatibility + Go/No-Go |
| **4.2** | `api-deprecation-check.sh`  | Deprecated / removed API audit            |
| **4.3** | `pdb-preupgrade-check.sh`   | Blocking PDB detection                    |
| **4.4** | `capacity-scaling-check.sh` | Autoscaler, capacity & HPA readiness      |

### CI/CD

* **One Jenkins pipeline**
* Fails immediately on **NO-GO**
* Archives audit evidence

---

# Directory Structure (Recommended)

```
preflight-checks/
├── eks-preupgrade-check.sh
├── api-deprecation-check.sh
├── pdb-preupgrade-check.sh
├── capacity-scaling-check.sh
└── Jenkinsfile
```

---

# Script 4.1 – Add-on Compatibility & Go/No-Go

> **Already validated by you – included for completeness**

📌 **File:** `eks-preupgrade-check.sh`
📌 **Purpose:** Verify add-on compatibility against target K8s version

👉 **Use the exact script you already confirmed working**
(No changes required)

---

# Script 4.2 – API Deprecation & Removal Audit

📌 **File:** `api-deprecation-check.sh`

```bash
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
```

---

# Script 4.3 – Blocking PDB Detection

📌 **File:** `pdb-preupgrade-check.sh`

```bash
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
```

---

# Script 4.4 – Capacity & Scaling Readiness

📌 **File:** `capacity-scaling-check.sh`

```bash
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
```

---

# Jenkins Pipeline – Execute 4.1 → 4.4

📌 **File:** `Jenkinsfile`

```groovy
pipeline {
  agent any

  environment {
    CLUSTER_NAME = "prod-eks"
    AWS_REGION   = "us-east-1"
    TARGET_K8S   = "1.34"
  }

  stages {

    stage('4.1 Add-on Compatibility Check') {
      steps {
        sh "./eks-preupgrade-check.sh ${CLUSTER_NAME} ${AWS_REGION} ${TARGET_K8S}"
      }
    }

    stage('4.2 API Deprecation Audit') {
      steps {
        sh "./api-deprecation-check.sh"
      }
    }

    stage('4.3 PDB Validation') {
      steps {
        sh "./pdb-preupgrade-check.sh"
      }
    }

    stage('4.4 Capacity & Scaling Readiness') {
      steps {
        sh "./capacity-scaling-check.sh"
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '*.txt', fingerprint: true
    }
    success {
      echo "✅ PRE-UPGRADE CHECKS PASSED – SAFE TO PROCEED"
    }
    failure {
      echo "❌ PRE-UPGRADE CHECK FAILED – UPGRADE BLOCKED"
    }
  }
}
```

---

# How This Works in Production

1. Jenkins triggers pipeline
2. Each step **hard-fails on risk**
3. Reports archived for:

   * CAB
   * Audit
   * Incident review
4. Upgrade proceeds **only if all steps PASS**

---

# Executive Rule (Very Important)

> **If this pipeline fails, the Kubernetes upgrade is NOT allowed.**

This is exactly how **Tier-0 production EKS upgrades** are gated.

---

## Next Logical Steps

When you’re ready, I can:

* Merge all checks into **one master script**
* Add **Slack / email notifications**
* Add **auto-remediation (guarded)**
* Extend pipeline to **perform the actual upgrade**
* Convert everything into a **formal enterprise SOP**

Just tell me what you want to do next.
