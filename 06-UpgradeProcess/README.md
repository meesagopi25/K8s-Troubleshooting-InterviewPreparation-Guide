
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

Run **before every upgrade**:

```bash
kubectl api-resources
kubectl get --raw /metrics | grep deprecated
```

Recommended tools:

* `kubent`
* `pluto`

**Block upgrade if:**

* Deprecated APIs are still in use
* CRDs target removed API versions

---

### 4.3 PodDisruptionBudget (PDB) Review

```bash
kubectl get pdb -A
```

Ensure:

* Replicas ≥ 2
* PDB allows at least 1 pod eviction

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
