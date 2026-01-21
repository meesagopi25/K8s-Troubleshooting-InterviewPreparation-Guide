
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
