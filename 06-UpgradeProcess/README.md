
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

### 4.1 Version Compatibility Check

Confirm compatibility for:

* Kubernetes target version
* CNI (Calico / VPC CNI)
* CoreDNS
* kube-proxy
* CSI drivers (EBS/EFS)
* Ingress controllers
* Service mesh (Istio, Linkerd)
* Admission controllers (OPA/Kyverno)

> **Rule:** No unsupported add-ons in prod.

Below is a **hands-on, production-grade “HOW TO” guide** for **Section 4.1 – Version Compatibility Check**, with **exact commands, decision points, and pass/fail criteria**.
This is written so you can **execute it step by step before a Kubernetes upgrade** (example: **1.33 → 1.34**), especially on **Amazon EKS**.

---

# 4.1 Version Compatibility Check – HOW TO (Production Grade)

## Objective

Ensure **every cluster component is supported** on the **target Kubernetes version** *before* upgrade.

**Golden rule**

> If any component is unsupported → **STOP THE UPGRADE**

---

## STEP 0: Define Current and Target Versions

### Get current Kubernetes version

```bash
kubectl version --short
```

Example:

```
Server Version: v1.33.4
```

### Define target version

```
Target: v1.34.x
```

---

## STEP 1: Kubernetes Version Support (Baseline)

### For EKS

Check supported versions:

```bash
aws eks describe-addon-versions --kubernetes-version 1.34
```

✔ PASS if:

* Target version is listed
* Add-ons support that version

❌ FAIL if:

* Version not listed (upgrade blocked)

---

## STEP 2: CNI Compatibility

### A. AWS VPC CNI (EKS default)

#### Check installed version

```bash
kubectl -n kube-system get daemonset aws-node \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Example:

```
amazon/aws-vpc-cni:v1.18.1
```

#### Check supported version

```bash
aws eks describe-addon-versions \
  --addon-name vpc-cni \
  --kubernetes-version 1.34
```

✔ PASS if:

* Installed version ≤ supported version
* Upgrade path exists

❌ FAIL if:

* Version not supported on target Kubernetes

---

### B. Calico (if used)

```bash
kubectl get pods -n calico-system
kubectl get ds -n calico-system calico-node \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Check Calico compatibility matrix:

* Kubernetes version
* Calico release

✔ PASS only if explicitly supported

---

## STEP 3: CoreDNS Compatibility

### Check current version

```bash
kubectl -n kube-system get deployment coredns \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Example:

```
coredns/coredns:v1.11.1
```

### Check target compatibility

```bash
aws eks describe-addon-versions \
  --addon-name coredns \
  --kubernetes-version 1.34
```

✔ PASS if:

* CoreDNS version is listed for target K8s

❌ FAIL if:

* CoreDNS version unsupported (DNS outage risk)

---

## STEP 4: kube-proxy Compatibility

### Check current version

```bash
kubectl -n kube-system get daemonset kube-proxy \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Example:

```
eks/kube-proxy:v1.33.4
```

### Check target compatibility

```bash
aws eks describe-addon-versions \
  --addon-name kube-proxy \
  --kubernetes-version 1.34
```

✔ PASS if:

* kube-proxy version aligns with target Kubernetes

---

## STEP 5: CSI Drivers (Storage – CRITICAL)

### A. EBS CSI Driver

```bash
kubectl get pods -n kube-system | grep ebs
```

```bash
kubectl -n kube-system get deployment ebs-csi-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Check compatibility:

```bash
aws eks describe-addon-versions \
  --addon-name aws-ebs-csi-driver \
  --kubernetes-version 1.34
```

✔ PASS if supported
❌ FAIL = **volume attach failures**

---

### B. EFS CSI Driver (if used)

```bash
kubectl get pods -n kube-system | grep efs
```

Validate version against AWS docs for target Kubernetes.

---

## STEP 6: Ingress Controller Compatibility

### Identify ingress controller

```bash
kubectl get pods -A | grep ingress
```

Common ones:

* NGINX Ingress
* ALB Controller
* Traefik

### Example: AWS Load Balancer Controller

```bash
kubectl -n kube-system get deployment aws-load-balancer-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Check version compatibility:

```bash
aws eks describe-addon-versions \
  --addon-name aws-load-balancer-controller \
  --kubernetes-version 1.34
```

✔ PASS if compatible
❌ FAIL = **traffic outage risk**

---

## STEP 7: Service Mesh Compatibility

### A. Istio

**Istio**

```bash
istioctl version
```

Check Istio support matrix:

* Kubernetes 1.34 supported?
* Control plane + data plane compatible?

✔ PASS only if explicitly supported

---

### B. Linkerd

**Linkerd**

```bash
linkerd version
```

Validate against Linkerd compatibility docs.

---

## STEP 8: Admission Controllers (OPA / Kyverno)

### A. OPA Gatekeeper

**OPA Gatekeeper**

```bash
kubectl get pods -n gatekeeper-system
```

Check:

* Gatekeeper version
* Kubernetes API compatibility
* CRDs supported

---

### B. Kyverno

**Kyverno**

```bash
kubectl get pods -n kyverno
```

Verify Kyverno supports target Kubernetes version.

❌ If incompatible → **disable policies before upgrade**

---

## STEP 9: Deprecated API Check (MANDATORY)

```bash
kubectl api-resources
```

Recommended tools:

```bash
kubent
pluto detect-all-in-cluster
```

❌ FAIL if:

* Deprecated APIs removed in target version are still used

---

## STEP 10: Decision Matrix (GO / NO-GO)

| Component             | Status      |
| --------------------- | ----------- |
| Kubernetes version    | PASS / FAIL |
| CNI                   | PASS / FAIL |
| CoreDNS               | PASS / FAIL |
| kube-proxy            | PASS / FAIL |
| CSI drivers           | PASS / FAIL |
| Ingress               | PASS / FAIL |
| Service mesh          | PASS / FAIL |
| Admission controllers | PASS / FAIL |

### Upgrade is allowed ONLY if:

```
ALL = PASS
```

---

## Production Rule (Non-Negotiable)

> **Never upgrade Kubernetes hoping add-ons will work.**
> Upgrade **add-ons first**, then Kubernetes.

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
