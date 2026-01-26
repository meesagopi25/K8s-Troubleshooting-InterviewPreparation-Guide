Below is a **complete, production-grade Kubernetes upgrade runbook for Amazon EKS**, covering **control plane + worker nodes**, fully aligned with **everything you have built so far**:

* Self-managed workers
* Automatic AMI lookup via SSM
* Terraform + Jenkins orchestration
* Safe drain, rollback, and validation
* Enterprise change-management style

This can be **directly added to your official upgrade SOP / runbook**.

---

# EKS Kubernetes Upgrade Runbook

**(Control Plane + Worker Nodes)**

---

## 1. Purpose

This runbook defines the **standard, production-approved procedure** to upgrade:

* Amazon EKS **control plane**
* **Self-managed worker nodes** (ASG-based)

The objective is to achieve:

* Zero or minimal downtime
* No data loss
* Full rollback capability
* Auditability and repeatability

---

## 2. Scope

Applies to:

* Amazon EKS clusters
* Self-managed worker nodes using Auto Scaling Groups
* CI/CD-driven upgrades using Jenkins and Terraform

Out of scope:

* Bare-metal Kubernetes
* In-place node upgrades (explicitly forbidden)

---

## 3. Upgrade Strategy (High Level)

```
Pre-checks
   ↓
Backup
   ↓
Control Plane Upgrade
   ↓
Post-Control Plane Validation
   ↓
Worker Node Upgrade (New ASG)
   ↓
Drain Old Nodes
   ↓
Post-Upgrade Validation
```

---

## 4. Preconditions (MANDATORY)

### 4.1 Version Compatibility (GO / NO-GO Gate)

Validate:

* Target Kubernetes version is supported by AWS
* Add-ons compatible:

  * VPC CNI
  * CoreDNS
  * kube-proxy
  * CSI drivers
  * Ingress controllers
* No deprecated APIs in use

Tools:

* `kubent`
* `pluto`
* Pre-upgrade compatibility script

**Upgrade is BLOCKED if any incompatibility exists.**

---

### 4.2 Backup (MANDATORY)

Take a **full cluster backup** before any upgrade.

```bash
velero backup create pre-upgrade-backup \
  --include-namespaces '*' \
  --snapshot-volumes \
  --wait
```

Verify backup status:

```bash
velero backup describe pre-upgrade-backup
```

---

### 4.3 Capacity & Scaling Readiness

Confirm:

* At least **one node worth of spare capacity**
* PodDisruptionBudgets allow eviction
* Critical workloads have replicas ≥ 2

```bash
kubectl get pdb -A
kubectl get nodes
```

---

## 5. Control Plane Upgrade

### 5.1 Upgrade Control Plane (AWS Managed)

Control plane is upgraded **first**.

```bash
aws eks update-cluster-version \
  --name <cluster-name> \
  --kubernetes-version <target-version>
```

Monitor:

```bash
aws eks describe-cluster --name <cluster-name>
```

Wait until:

```
status: ACTIVE
```

---

### 5.2 Control Plane Validation

```bash
kubectl version
kubectl get nodes
kubectl get pods -A
```

Expected:

* API server reachable
* No systemic failures
* Workers still functional (older kubelet allowed temporarily)

---

## 6. Worker Node Upgrade (Self-Managed – Option B)

### 6.1 Core Principle (Immutable Upgrade)

> **Worker nodes are NEVER upgraded in place.**
> They are **replaced** using a new Auto Scaling Group.

---

## 7. Jenkins-Driven Worker Upgrade (Authoritative Process)

### 7.1 Inputs to Jenkins

| Parameter    | Example   |
| ------------ | --------- |
| CLUSTER_NAME | prod-eks  |
| AWS_REGION   | us-east-1 |
| K8S_VERSION  | 1.34      |
| APPLY        | true      |

---

### 7.2 What Jenkins Does (In Order)

1. Checkout Git repo
2. Terraform init + validate
3. Automatically resolve EKS AMI using SSM:

   ```
   /aws/service/eks/optimized-ami/1.34/amazon-linux-2/recommended/image_id
   ```
4. Create **new Launch Template**
5. Create **new Auto Scaling Group**
6. New EC2 nodes launch
7. `/etc/eks/bootstrap.sh` joins nodes to cluster
8. Jenkins waits until new nodes are **Ready**
9. Jenkins drains **old ASG nodes one by one**

---

## 8. Drain Logic (Critical Safety Controls)

Drain is performed using:

```bash
kubectl cordon <node>
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=10m
```

Guarantees:

* PDBs respected
* Stateful workloads protected
* One-node-at-a-time eviction

---

## 9. Post-Upgrade Validation

### 9.1 Node Validation

```bash
kubectl get nodes -o wide
kubectl describe node <new-node> | grep "Kubelet Version"
```

Expected:

```
Kubelet Version: v<target-version>.x
```

---

### 9.2 Workload Validation

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get endpoints -A
```

Ensure:

* All pods Running/Ready
* No CrashLoopBackOff
* No service impact

---

## 10. Rollback Strategy (Guaranteed)

Rollback is **always possible** because:

* Old ASG is untouched until drain
* Control plane upgrades are backward compatible (±1 version)
* Data volumes are persistent

### Rollback Options

| Scenario        | Action                   |
| --------------- | ------------------------ |
| New ASG failure | Stop Jenkins job         |
| App instability | Scale old ASG up         |
| Partial drain   | Uncordon remaining nodes |
| Severe issue    | Delete new ASG           |

---

## 11. Post-Upgrade Cleanup (Optional)

After soak period (24–72 hours):

```bash
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name <old-asg> \
  --force-delete
```

---

## 12. Operational Guardrails (MANDATORY)

* No upgrades during peak hours
* Manual approval gate required
* One cluster at a time
* Observability dashboards monitored during upgrade
* On-call engineer present

---

## 13. Key Rules (Non-Negotiable)

* ❌ No in-place node upgrades
* ❌ No skipping backups
* ❌ No draining without spare capacity
* ✅ Immutable infrastructure only
* ✅ Git-driven automation
* ✅ Rollback always preserved

---

## 14. Executive Summary

> This runbook defines a safe, repeatable, and fully automated EKS upgrade process that upgrades the control plane first, then replaces worker nodes using immutable infrastructure, ensuring zero downtime, data safety, and guaranteed rollback.

---

If you want next, I can:

* Convert this into **PDF / Confluence format**
* Add **change-ticket templates**
* Add **Kafka-specific upgrade section**
* Add **managed node group variant**
* Add **diagrammatic sequence flow**

Just tell me.
