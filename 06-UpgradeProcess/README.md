
Below is a **production-grade, end-to-end Kubernetes upgrade runbook** suitable for **enterprise environments**, including **prerequisites, risk controls, backups, execution steps, validation, and rollback**.
This applies to **managed Kubernetes (EKS/GKE/AKS)** and **self-managed clusters**, with **Amazon EKS** called out where behavior is EKS-specific.

---

# Kubernetes Upgrade Runbook (Production Grade)

---

## 1. Purpose and Scope

### Purpose

To upgrade a Kubernetes cluster **safely and predictably** while:

* Preserving workload availability
* Avoiding data loss
* Maintaining auditability
* Providing fast rollback options

### In Scope

* Control plane upgrade
* Worker node upgrade
* Add-on compatibility
* Backup and restore
* Rollback and disaster recovery

### Out of Scope

* Application code changes
* Database engine upgrades

---

## 2. Upgrade Principles (Non-Negotiable)

1. **Sequential minor versions only**
   (e.g., 1.33 → 1.34; never skip versions)

2. **One change per upgrade**

   * No app changes
   * No config refactors
   * No add-on experiments

3. **Rollback must be defined before execution**

4. **Non-prod upgraded first**

   * Minimum soak period: **7–30 days**

---

## 3. Roles and Responsibilities

| Role               | Responsibility            |
| ------------------ | ------------------------- |
| Platform / SRE     | Upgrade execution         |
| Application Owners | App validation            |
| Security           | Policy & admission checks |
| Change Manager     | CAB approval              |
| Incident Manager   | Rollback coordination     |

---

## 4. Pre-Upgrade Prerequisites (MANDATORY)

Below is a **production-grade `README.md` section** you can **directly paste into your Kubernetes Upgrade Runbook** as **Section 4.1 – Version Compatibility Check**.
It is written in **audit-friendly, enterprise documentation style** and explicitly explains the **script purpose, usage, logic, outputs, and Go/No-Go criteria**.

---

# 4.1 Version Compatibility Check (MANDATORY)

## Purpose

Before upgrading Kubernetes, **all cluster add-ons and integrations MUST be verified for compatibility with the target Kubernetes version**.
This step prevents **cluster outages, networking failures, storage attach errors, and admission controller blocks**.

This organization uses an **automated pre-upgrade compatibility script** to enforce this requirement for **Amazon EKS** clusters.

---

## Why This Step Is Mandatory

Kubernetes **minor version upgrades can remove APIs and change behavior**.
If any add-on is incompatible:

* Nodes may fail to join the cluster
* Pods may not receive IP addresses
* DNS may stop resolving
* Persistent volumes may fail to attach
* Admission controllers may block workloads

**Rule (Non-Negotiable)**

> **If ANY component is incompatible, the upgrade must NOT proceed.**

---

## Scope of Compatibility Validation

The automated check validates compatibility for:

* Kubernetes control plane (current vs target)
* AWS VPC CNI
* CoreDNS
* kube-proxy
* EBS CSI driver
* EFS CSI driver
* Ingress controllers (AWS Load Balancer Controller)
* Service mesh (Istio / Linkerd – detection + guardrail)
* Admission controllers (OPA Gatekeeper / Kyverno – detection + guardrail)

---

## Automation Used

Script name:

```
eks-preupgrade-check.sh
```

Purpose:

* Collect current component versions
* Query AWS for **officially supported versions** for the target Kubernetes release
* Perform **automatic PASS / FAIL decisions**
* Generate a **formal Go / No-Go report**

This script is **read-only** and safe to run in production environments.

---

## Prerequisites

Before running the script, ensure:

* `kubectl` is configured for the target cluster
* `aws` CLI is configured with permissions:

  * `eks:ListAddons`
  * `eks:DescribeAddon`
  * `eks:DescribeAddonVersions`
* `jq` is installed on the execution host

---

## Script Usage

```bash
./eks-preupgrade-check.sh <cluster-name> <aws-region> <target-k8s-version>
```

### Example

```bash
./eks-preupgrade-check.sh prod-eks us-east-1 1.34
```

---

## What the Script Does (Execution Logic)

1. **Detects current Kubernetes server version**
2. **Enumerates EKS-managed add-ons**
3. **Queries AWS support matrix** for the target Kubernetes version
4. **Compares installed vs supported versions**
5. **Detects risk components** that require manual verification
6. **Generates a formal Go / No-Go decision**

---

## Output Artifacts

### 1. Console Output

Immediate visibility during execution.

### 2. Go / No-Go Report File

Generated file:

```
eks-upgrade-go-nogo-report.txt
```

This file is:

* Attached to CAB tickets
* Archived in CI/CD pipelines
* Stored as upgrade evidence

---

## Sample Report (Excerpt)

```
[EKS Managed Add-ons Compatibility]
[vpc-cni]
Installed Version : v1.21.1-eksbuild.1
Supported Versions: v1.21.0-eksbuild.4 v1.21.1-eksbuild.1
✅ PASS

[coredns]
Installed Version : v1.11.1-eksbuild.3
Supported Versions: v1.11.1-eksbuild.4
❌ FAIL

==================================================
FINAL DECISION: ❌ NO-GO – REMEDIATION REQUIRED
==================================================
```

---

## Decision Criteria (Go / No-Go)

### ✅ GO (Upgrade Allowed)

* All EKS-managed add-ons show **PASS**
* No incompatible service mesh detected
* No blocking admission controllers detected
* FINAL DECISION = **GO**

### ❌ NO-GO (Upgrade Blocked)

Upgrade must be **stopped immediately** if:

* Any add-on version is unsupported
* Service mesh compatibility is unknown
* Admission controllers require review
* FINAL DECISION = **NO-GO**

---

## Required Actions on NO-GO

If the report indicates **NO-GO**:

1. Upgrade incompatible add-ons **first**
2. Validate upgraded add-ons are running
3. Re-run the script
4. Proceed only when FINAL DECISION = **GO**

---

## Integration With Upgrade Workflow

This step is executed:

* **Before** control plane upgrade
* **Before** node group upgrades
* **Before** CAB approval is finalized

### CI/CD Integration (Recommended)

This script is executed as a **pre-flight gate** in Jenkins pipelines.
Pipeline execution **must fail automatically** if FINAL DECISION = NO-GO.

---

## Audit and Compliance Notes

* Output report is retained for **change records**
* Script ensures upgrades are:

  * Predictable
  * Repeatable
  * Vendor-supported
* Prevents undocumented, risky upgrades

---

## Summary

This compatibility check ensures that:

* Kubernetes upgrades are **safe**
* Add-ons remain **vendor-supported**
* Failures are detected **before production impact**
* Upgrade decisions are **evidence-based**

**No compatibility check = No upgrade.**

---

### Next Runbook Step

Proceed to **4.2 – API Deprecation and Removal Audit** only if:

```
FINAL DECISION = GO
```

---

If you want, I can also:

* Convert this into a **PDF runbook**
* Add a **diagram showing upgrade dependency order**
* Provide a **CAB approval template**
* Integrate this section into your **Terraform/Jenkins upgrade SOP**

Just tell me how you want to proceed.

---

### 4.2 API Deprecation & Removal Audit

Below is a **production-grade, step-by-step runbook section** for **4.2 – API Deprecation & Removal Audit**, written so it can be **directly added to your upgrade run book** and **executed by SREs without ambiguity**.

This section explains **what to run, why to run it, how to interpret results, and when to BLOCK the upgrade**.

---

# 4.2 API Deprecation & Removal Audit (MANDATORY)

## Objective

Identify **deprecated or removed Kubernetes APIs** that will **break workloads after a Kubernetes upgrade**.

**Why this is critical**

* Kubernetes **removes APIs permanently** in newer versions
* Objects using removed APIs:

  * Fail to create
  * Fail to reconcile
  * Can crash controllers
* CRDs are especially dangerous because failures are often silent

**Rule (Non-Negotiable)**

> **If deprecated or removed APIs are in use, the upgrade MUST be blocked.**

---

## When This Step Must Be Run

* **Before every Kubernetes minor version upgrade**
* **After add-on upgrades**
* **Before CAB / change approval**
* **Before production rollout**

---

## Inputs Required

* Access to the cluster via `kubectl`
* Target Kubernetes version (example: `1.34`)
* Read access to all namespaces

---

## Step 1: Establish Current and Target Kubernetes Versions

```bash
kubectl version -o json | jq -r '.serverVersion.gitVersion'
```

Example:

```
v1.33.4
```

Target:

```
1.34
```

---

## Step 2: Baseline API Resource Inventory

### Command

```bash
kubectl api-resources
```

### Purpose

* Lists **all API resources currently registered** in the cluster
* Includes:

  * Core APIs
  * CRDs
  * Aggregated APIs

### What to Look For

* Older API groups such as:

  * `extensions/v1beta1`
  * `apps/v1beta1`
  * `apps/v1beta2`
  * `networking.k8s.io/v1beta1`
  * `apiextensions.k8s.io/v1beta1`

### Decision

| Result                         | Action            |
| ------------------------------ | ----------------- |
| Only stable APIs (`v1`)        | Continue          |
| Beta / deprecated APIs present | Proceed to Step 3 |
| Removed APIs present           | **BLOCK UPGRADE** |

---

## Step 3: Detect Deprecated API Usage via Metrics

### Command

```bash
kubectl get --raw /metrics | grep -i deprecated
```

### What This Does

* Queries the API server metrics endpoint
* Detects **live usage of deprecated APIs**
* Captures:

  * Which API
  * Which client
  * Frequency of use

### Example Output

```
apiserver_requested_deprecated_apis{group="apps",version="v1beta1",resource="deployments"} 12
```

### Interpretation

| Observation      | Meaning                                  |
| ---------------- | ---------------------------------------- |
| Metric present   | Deprecated API actively used             |
| Metric count > 0 | Workloads/controllers still depend on it |
| No output        | No deprecated API usage detected         |

### Decision

* **Any output = FAIL**
* **Upgrade must be blocked until remediated**

---

## Step 4: Detect Deprecated APIs in Live Objects (kubectl-native)

### Command

```bash
kubectl get all -A -o yaml | grep -E "apiVersion:.*v1beta|extensions"
```

### Purpose

* Finds workloads using deprecated API versions
* Covers:

  * Deployments
  * DaemonSets
  * StatefulSets
  * Ingress
  * Network policies

### Decision

| Result        | Action          |
| ------------- | --------------- |
| No matches    | Continue        |
| Matches found | Upgrade blocked |

---

## Step 5: Run `kubent` (Kubernetes No-Trouble)

### Tool Purpose

`kubent` scans the **entire cluster** and reports:

* Deprecated APIs
* Removed APIs
* Version in which APIs will be removed

### Installation

```bash
curl -sSL https://github.com/doitintl/kube-no-trouble/releases/latest/download/kubent-linux-amd64 \
  -o kubent
chmod +x kubent
sudo mv kubent /usr/local/bin/
```

### Execution

```bash
kubent
```

### Example Output

```
Found deprecated API:
- apps/v1beta1 Deployment (removed in 1.16)
- networking.k8s.io/v1beta1 Ingress (removed in 1.22)
```

### Decision

| kubent Output         | Action            |
| --------------------- | ----------------- |
| No deprecated APIs    | PASS              |
| Deprecated APIs found | **BLOCK UPGRADE** |

---

## Step 6: Run `pluto` (CRD-Focused Audit)

### Tool Purpose

`pluto` is **mandatory** if your cluster uses:

* Operators
* CRDs
* Service meshes
* Custom controllers

It detects:

* Deprecated APIs
* Removed APIs
* CRDs using invalid versions

### Installation

```bash
curl -sSL https://github.com/FairwindsOps/pluto/releases/latest/download/pluto_linux_amd64.tar.gz | tar xz
sudo mv pluto /usr/local/bin/
```

### Cluster-wide Scan

```bash
pluto detect-all-in-cluster
```

### Target-version Scan (Recommended)

```bash
pluto detect-all-in-cluster --target-versions k8s=v1.34
```

### Example Output

```
CRD myresource.example.com uses apiextensions.k8s.io/v1beta1
REMOVED IN v1.22
```

### Decision

| Pluto Result    | Action              |
| --------------- | ------------------- |
| No findings     | PASS                |
| Deprecated CRDs | Upgrade blocked     |
| Removed CRDs    | **IMMEDIATE BLOCK** |

---

## Step 7: CRD Version Audit (Manual Safety Net)

### Command

```bash
kubectl get crds -o json | jq -r '.items[].spec.versions[].name'
```

Verify:

* CRDs use `apiextensions.k8s.io/v1`
* No `v1beta1` definitions exist

---

## Step 8: Go / No-Go Criteria

### ✅ GO (Proceed to Next Step)

All conditions must be true:

* No deprecated APIs in `/metrics`
* `kubent` shows no deprecated APIs
* `pluto` shows no deprecated or removed APIs
* All CRDs use supported API versions

---

### ❌ NO-GO (Upgrade Blocked)

Upgrade must be **stopped immediately** if **ANY** of the following are true:

* Deprecated APIs detected
* Removed APIs detected
* CRDs target unsupported API versions
* Operators depend on removed APIs

---

## Step 9: Required Remediation Before Proceeding

If NO-GO:

1. Update manifests to supported API versions
2. Upgrade operators/controllers
3. Reapply CRDs
4. Re-run **ALL checks**
5. Proceed only after **zero findings**

---

## Step 10: Evidence to Capture (Audit Requirement)

Save outputs:

```bash
kubectl api-resources > api-resources.txt
kubectl get --raw /metrics | grep deprecated > deprecated-metrics.txt
kubent > kubent-report.txt
pluto detect-all-in-cluster --target-versions k8s=v1.34 > pluto-report.txt
```

Attach these files to:

* CAB ticket
* Upgrade record
* CI/CD artifacts

---

## Summary (Executive Level)

* APIs are **removed permanently** in Kubernetes
* Deprecated APIs **will break silently**
* This audit is **mandatory**
* **No clean report = No upgrade**

---

### Next Runbook Step

Proceed to **4.3 – PodDisruptionBudget & Workload Readiness Validation** only if:

```
ALL API AUDITS = PASS
```

If you want, next I can:

* Add this as an **automated Jenkins gate**
* Integrate API checks into your existing script
* Provide **real-world remediation examples**
* Map deprecated APIs specifically for **1.33 → 1.34**

Just tell me how you want to proceed.

---

### 4.3 PodDisruptionBudget (PDB) Review

Below is a **production-grade, step-by-step runbook section** for **4.3 – PodDisruptionBudget (PDB) Review**, written to be **directly inserted into your Kubernetes upgrade run book** and **executed without interpretation errors**.

This step ensures **workload availability during node draining and rolling upgrades**.

---

# 4.3 PodDisruptionBudget (PDB) Review (MANDATORY)

## Objective

Ensure that **workloads can tolerate pod evictions** during:

* Node upgrades
* Node drains
* Cluster autoscaling events

**Why this is critical**

* During upgrades, Kubernetes evicts pods
* Overly strict PDBs **block node drains**
* Single-replica workloads with PDBs cause **upgrade deadlocks**

**Rule (Non-Negotiable)**

> **If PDBs block evictions, the upgrade MUST NOT proceed.**

---

## When This Step Must Be Run

* Before control plane upgrade
* Before worker node upgrades
* After add-on upgrades
* During every production upgrade

---

## Step 1: List All PDBs Cluster-Wide

```bash
kubectl get pdb -A
```

### Example Output

```
NAMESPACE   NAME                 MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS
prod        api-pdb              1               N/A               0
prod        worker-pdb            2               N/A               1
kube-system coredns-pdb           1               N/A               1
```

---

## Step 2: Understand the Columns (Critical)

| Column              | Meaning                         |
| ------------------- | ------------------------------- |
| MIN AVAILABLE       | Pods that must remain running   |
| MAX UNAVAILABLE     | Pods allowed to be disrupted    |
| ALLOWED DISRUPTIONS | Evictions allowed **right now** |

**Key field:**

> **`ALLOWED DISRUPTIONS`**

If this is `0`, **node drain will fail**.

---

## Step 3: Mandatory Validation Rules

### Rule 1: Replicas ≥ 2

Check replica count:

```bash
kubectl get deploy,statefulset -A
```

**Decision**

| Replica Count | Result          |
| ------------- | --------------- |
| ≥ 2           | OK              |
| 1             | ⚠️ High risk    |
| 1 + PDB       | ❌ BLOCK UPGRADE |

---

### Rule 2: PDB Allows ≥ 1 Eviction

```bash
kubectl describe pdb <pdb-name> -n <namespace>
```

Example:

```
Allowed disruptions: 0
```

**Decision**

| Allowed Disruptions | Result |
| ------------------- | ------ |
| ≥ 1                 | PASS   |
| 0                   | ❌ FAIL |

---

## Step 4: Identify Blocking PDBs (Automated)

### Command

```bash
kubectl get pdb -A | awk '$4 == 0 {print}'
```

This lists **all PDBs blocking eviction**.

---

## Step 5: Deep-Dive on Blocking PDBs

For each blocking PDB:

```bash
kubectl describe pdb <pdb-name> -n <namespace>
```

Look for:

* `minAvailable`
* `maxUnavailable`
* Target selector

---

## Step 6: Common Failure Patterns & Fixes

### ❌ Pattern 1: Single Replica + PDB

Example:

```yaml
replicas: 1
minAvailable: 1
```

**Result:**

* No eviction possible
* Node drain blocked

**Fix (Temporary for upgrade)**

```yaml
minAvailable: 0
```

or scale replicas:

```bash
kubectl scale deploy <name> -n <ns> --replicas=2
```

---

### ❌ Pattern 2: PDB Too Strict

Example:

```yaml
replicas: 3
minAvailable: 3
```

**Result:**

* Zero evictions allowed

**Fix**

```yaml
minAvailable: 2
```

or

```yaml
maxUnavailable: 1
```

---

## Step 7: System Namespace Special Cases

### CoreDNS (Important)

```bash
kubectl get pdb -n kube-system coredns-pdb
```

Ensure:

* Replicas ≥ 2
* Allowed disruptions ≥ 1

If CoreDNS blocks eviction:

* DNS outage risk
* Upgrade must be stopped

---

## Step 8: Dry-Run Node Drain Test (Recommended)

Before upgrading:

```bash
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

If this fails:

* Identify blocking PDB
* Fix before proceeding

---

## Step 9: Go / No-Go Decision

### ✅ GO (Proceed)

All conditions met:

* No PDB with `ALLOWED DISRUPTIONS = 0`
* All critical workloads have replicas ≥ 2
* System workloads (CoreDNS, ingress) are evictable

---

### ❌ NO-GO (Block Upgrade)

Upgrade is blocked if:

* Any PDB blocks eviction
* Any single-replica workload has a PDB
* CoreDNS cannot be evicted

---

## Step 10: Evidence Collection (Audit)

Save outputs:

```bash
kubectl get pdb -A > pdb-list.txt
kubectl get deploy,statefulset -A > workload-replicas.txt
```

Attach to:

* Change ticket
* Upgrade runbook
* CI/CD artifacts

---

## Summary (Executive)

* PDBs protect availability **but can block upgrades**
* Eviction must be possible **before draining nodes**
* One blocking PDB can stall the entire upgrade
* This check prevents **mid-upgrade outages**

---

## Next Runbook Step

Proceed to:

### **4.4 Capacity & Scaling Readiness Check**

Only after:

```
ALL PDB CHECKS = PASS
```

---

If you want, I can next:

* Provide **automation to detect & flag blocking PDBs**
* Add this as a **Jenkins pre-flight gate**
* Show **real remediation examples from prod**
* Integrate PDB checks into your existing script

Just tell me the next step.

Below is a **production-grade automation** to **detect, flag, and report blocking PodDisruptionBudgets (PDBs)**.
It is **read-only**, **safe for production**, and designed to be used **standalone or as a CI/CD gate**.

You can drop this directly into your upgrade toolkit and reference it in **Runbook §4.3**.

---

# Automation: Detect & Flag Blocking PDBs

## What This Automation Does

It automatically:

* Lists **all PDBs** across namespaces
* Flags PDBs where **`allowedDisruptions = 0`**
* Cross-checks **target workload replica counts**
* Detects **high-risk patterns**:

  * Single replica + PDB
  * PDB minAvailable too strict
* Generates a **GO / NO-GO decision**
* Produces an **audit-ready report**

---

## Prerequisites

* `kubectl` access to the cluster
* Read access to all namespaces
* Bash shell

No cluster changes are made.

---

## Usage

```bash
./pdb-preupgrade-check.sh
```

Optional (recommended for CI/CD):

```bash
./pdb-preupgrade-check.sh && echo "GO" || echo "NO-GO"
```

---

## Script: `pdb-preupgrade-check.sh`

**COPY EXACTLY**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT="pdb-preupgrade-report.txt"
BLOCKING_FOUND=false

echo "==================================================" | tee "$REPORT"
echo "PDB PRE-UPGRADE SAFETY CHECK" | tee -a "$REPORT"
echo "Cluster        : $(kubectl config current-context)" | tee -a "$REPORT"
echo "Generated On   : $(date -u)" | tee -a "$REPORT"
echo "==================================================" | tee -a "$REPORT"
echo | tee -a "$REPORT"

log() {
  echo "$1" | tee -a "$REPORT"
}

fail() {
  log "❌ FAIL"
  BLOCKING_FOUND=true
}

pass() {
  log "✅ PASS"
}

# --------------------------------------------------
# Step 1: List all PDBs
# --------------------------------------------------
log "[PDB Inventory]"
kubectl get pdb -A -o wide | tee -a "$REPORT"
echo | tee -a "$REPORT"

# --------------------------------------------------
# Step 2: Detect blocking PDBs (allowedDisruptions = 0)
# --------------------------------------------------
log "[Blocking PDB Detection]"
BLOCKING_PDBS=$(kubectl get pdb -A -o json | jq -r '
  .items[] |
  select(.status.disruptionsAllowed == 0) |
  "\(.metadata.namespace) \(.metadata.name)"
')

if [[ -z "$BLOCKING_PDBS" ]]; then
  log "No blocking PDBs detected"
  pass
else
  log "Blocking PDBs found:"
  echo "$BLOCKING_PDBS" | tee -a "$REPORT"
  fail
fi

echo | tee -a "$REPORT"

# --------------------------------------------------
# Step 3: Analyze each blocking PDB
# --------------------------------------------------
if [[ -n "$BLOCKING_PDBS" ]]; then
  log "[Blocking PDB Analysis]"

  while read -r NS NAME; do
    log "------------------------------------------"
    log "Namespace : $NS"
    log "PDB       : $NAME"

    kubectl describe pdb "$NAME" -n "$NS" | tee -a "$REPORT"

    # Extract selector
    SELECTOR=$(kubectl get pdb "$NAME" -n "$NS" -o jsonpath='{.spec.selector.matchLabels}' | tr -d '{}')

    if [[ -n "$SELECTOR" ]]; then
      KEY=$(echo "$SELECTOR" | cut -d: -f1 | tr -d ' ')
      VALUE=$(echo "$SELECTOR" | cut -d: -f2 | tr -d ' ')

      log "Target Workloads (replica check):"
      kubectl get deploy,statefulset -n "$NS" \
        -l "$KEY=$VALUE" \
        -o custom-columns=KIND:.kind,NAME:.metadata.name,REPLICAS:.spec.replicas \
        --no-headers | tee -a "$REPORT"

      SINGLE_REPLICA=$(kubectl get deploy,statefulset -n "$NS" \
        -l "$KEY=$VALUE" \
        -o json | jq '[.items[] | select(.spec.replicas < 2)] | length')

      if [[ "$SINGLE_REPLICA" -gt 0 ]]; then
        log "❌ Single-replica workload protected by PDB"
        BLOCKING_FOUND=true
      fi
    else
      log "⚠️ Unable to determine selector targets"
      BLOCKING_FOUND=true
    fi

  done <<< "$BLOCKING_PDBS"
fi

echo | tee -a "$REPORT"

# --------------------------------------------------
# Step 4: Final Decision
# --------------------------------------------------
log "=================================================="
if $BLOCKING_FOUND; then
  log "FINAL DECISION: ❌ NO-GO – BLOCKING PDBs DETECTED"
  log "ACTION REQUIRED: Fix PDBs before upgrade"
  log "=================================================="
  exit 1
else
  log "FINAL DECISION: ✅ GO – NO BLOCKING PDBs"
  log "=================================================="
  exit 0
fi
```

---

## Make Executable

```bash
chmod +x pdb-preupgrade-check.sh
```

---

## Sample Output (Failure Case)

```
[Blocking PDB Detection]
Blocking PDBs found:
prod api-pdb
❌ FAIL

[Blocking PDB Analysis]
Namespace : prod
PDB       : api-pdb
Allowed disruptions: 0
Target Workloads:
Deployment api 1

❌ Single-replica workload protected by PDB

FINAL DECISION: ❌ NO-GO – BLOCKING PDBs DETECTED
```

---

## Sample Output (Success Case)

```
[Blocking PDB Detection]
No blocking PDBs detected
✅ PASS

FINAL DECISION: ✅ GO – NO BLOCKING PDBs
```

---

## CI/CD Integration (Jenkins)

Add this as a **hard gate** before upgrades:

```groovy
stage('PDB Pre-Upgrade Check') {
  steps {
    sh './pdb-preupgrade-check.sh'
  }
}
```

Pipeline will **fail automatically** on NO-GO.

---

## Operational Remediation Guidelines (When NO-GO)

| Issue                   | Fix                       |
| ----------------------- | ------------------------- |
| Single replica + PDB    | Scale replicas ≥ 2        |
| minAvailable too strict | Reduce minAvailable       |
| maxUnavailable = 0      | Set maxUnavailable = 1    |
| CoreDNS blocked         | Scale CoreDNS & relax PDB |

---

## Runbook Placement

Insert this automation under:

```
4.3 PodDisruptionBudget (PDB) Review
```

and mark as **MANDATORY PRE-FLIGHT CHECK**.

---

## Next Step in Upgrade Runbook

Proceed to:

### **4.4 Capacity & Scaling Readiness Validation**

If you want, I can next:

* Merge **4.1 + 4.2 + 4.3** into a single master script
* Add **auto-remediation (optional, guarded)**
* Provide a **dry-run node drain validator**
* Convert reports to **JSON for dashboards**

Just tell me the next step.


---

### 4.4 Capacity & Scaling Readiness

* Cluster autoscaler enabled
* Enough spare capacity to drain one node
* HPA functional

---

## 5. Backup Strategy (CRITICAL)

### 5.1 What Must Be Backed Up

| Component          | Tool / Method           |
| ------------------ | ----------------------- |
| Kubernetes objects | Velero                  |
| CRDs               | Velero                  |
| Namespaces         | Velero                  |
| PV data            | CSI snapshots           |
| Secrets            | Encrypted Velero backup |
| IAM mappings       | Export manually         |
| GitOps state       | Git repository          |

---

### 5.2 Execute Backup

```bash
velero backup create pre-upgrade-backup \
  --include-namespaces '*' \
  --snapshot-volumes \
  --wait
```

Validate:

```bash
velero backup describe pre-upgrade-backup
```

---

### 5.3 Manual Safety Exports (Enterprise Requirement)

```bash
kubectl get all -A -o yaml > cluster-objects.yaml
kubectl get crds -o yaml > crds.yaml
kubectl get cm -n kube-system aws-auth -o yaml > aws-auth.yaml
```

---

## 6. Change Management

* CAB approval obtained
* Maintenance window defined
* Rollback window defined
* Incident bridge ready
* Monitoring dashboards opened

---

## 7. Upgrade Execution – Control Plane

### 7.1 Managed Kubernetes (Example: EKS)

```bash
aws eks update-cluster-version \
  --name <cluster-name> \
  --kubernetes-version <target-version>
```

Validation:

```bash
kubectl version
```

**Important**

* Control plane upgrade is **irreversible**
* Rollback requires **parallel cluster strategy**

---

## 8. Upgrade Add-Ons (MANDATORY ORDER)

Upgrade immediately after control plane:

1. CNI
2. CoreDNS
3. kube-proxy
4. CSI drivers
5. Ingress controllers

Example (EKS):

```bash
aws eks update-addon \
  --cluster-name <cluster-name> \
  --addon-name coredns \
  --resolve-conflicts OVERWRITE
```

---

## 9. Worker Node Upgrade (Most Critical Phase)

### 9.1 Node Upgrade Strategy

| Node Type           | Strategy            |
| ------------------- | ------------------- |
| Managed Node Groups | Rolling replacement |
| Self-Managed        | New ASG + drain     |
| Bare metal          | Manual cordon/drain |

---

### 9.2 Safe Node Upgrade Procedure

For **each node**:

```bash
kubectl cordon <node>
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data
```

Replace node with new version.

Verify:

```bash
kubectl get nodes
```

Uncordon:

```bash
kubectl uncordon <node>
```

Upgrade **one node at a time**.

---

## 10. Post-Upgrade Validation (MANDATORY)

### 10.1 Cluster Health

```bash
kubectl get nodes
kubectl get pods -A
kubectl get events -A
```

### 10.2 Application Health

* Pod readiness
* Error rate
* Latency SLOs
* Autoscaling behavior
* Job/CronJob execution

### 10.3 Security Validation

* PodSecurity / PSA
* OPA/Kyverno policies
* IRSA / ServiceAccounts
* TLS certificates

---

## 11. Rollback Strategy (Enterprise-Grade)

### 11.1 Control Plane Rollback

❌ **Not supported**

**Mitigation options:**

* Blue/Green cluster
* Restore workloads to parallel cluster

---

### 11.2 Node Rollback

* Re-enable old node group
* Drain new nodes
* Delete failed nodes

---

### 11.3 Application Rollback

* Helm:

```bash
helm rollback <release> <revision>
```

* GitOps:

  * Re-sync last known good commit

---

### 11.4 Full Cluster Restore (Disaster Case)

```bash
velero restore create \
  --from-backup pre-upgrade-backup
```

Use only if:

* CRDs corrupted
* Admission controller failure
* API incompatibility widespread

---

## 12. Blue/Green Upgrade (Recommended for Tier-0)

When zero risk is required:

* Create parallel cluster
* Upgrade there
* Shift traffic
* Roll back instantly if needed

---

## 13. Post-Upgrade Actions

* Monitor for 24–72 hours
* Close CAB ticket
* Update documentation
* Update runbooks
* Schedule next upgrade

---

## 14. Common Failure Scenarios & Mitigation

| Failure                  | Mitigation                 |
| ------------------------ | -------------------------- |
| Pod stuck terminating    | Check PDB                  |
| CNI crash                | Roll back add-on           |
| Admission policy failure | Disable policy temporarily |
| API removal              | Restore from backup        |
| Node NotReady            | Roll back node group       |

---

## 15. Recommended Upgrade Cadence

| Environment | Frequency   |
| ----------- | ----------- |
| Dev         | Every minor |
| Test        | Every minor |
| Prod        | N-1 only    |

---

## 16. Final Checklist (Go/No-Go)

* [ ] Backup completed & verified
* [ ] No deprecated APIs
* [ ] PDBs validated
* [ ] Add-ons compatible
* [ ] Rollback plan approved
* [ ] Monitoring active

---

## Executive Summary

A safe Kubernetes upgrade is:

* **Planned**
* **Backed up**
* **Incremental**
* **Observable**
* **Rollback-ready**

If any of these are missing, **do not upgrade**.

---

### What I Can Do Next

If you want, I can:

* Convert this into a **formal SOP / PDF**
* Tailor it **specifically for EKS 1.33 → 1.34**
* Add **CI/CD automation (Terraform + Jenkins)**
* Provide a **Blue/Green architecture document**

Just tell me how you want to proceed.
