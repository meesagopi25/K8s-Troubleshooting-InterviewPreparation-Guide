Below is a **production-grade, step-by-step runbook** for **Node Upgrade Strategies**, aligned exactly to your table:

> **9.1 Node Upgrade Strategy**

| Node Type           | Strategy            |
| ------------------- | ------------------- |
| Managed Node Groups | Rolling replacement |
| Self-Managed        | New ASG + drain     |
| Bare metal          | Manual cordon/drain |

This is written in **enterprise SOP style** and suitable for **upgrade runbooks, audits, and change approvals**.

---

# 9.1 Node Upgrade Strategy – Detailed Procedures

---

## A. Managed Node Groups (EKS)

### Strategy: Rolling Replacement (AWS-managed)

> **Recommended and safest approach on EKS**

---

### A.1 Preconditions (MANDATORY)

* EKS control plane already upgraded
* Add-ons compatible with target version
* PDBs validated (`allowedDisruptions ≥ 1`)
* Sufficient spare capacity (or Cluster Autoscaler enabled)

---

### A.2 How Rolling Replacement Works (Concept)

1. EKS creates new nodes with target version/AMI
2. New nodes join the cluster
3. Old nodes are **cordoned**
4. Pods are **drained respecting PDBs**
5. Old nodes are terminated
6. Process repeats until complete

No SSH, no manual drain.

---

### A.3 Step-by-Step Execution

#### Step 1: Identify Node Group

```bash
aws eks list-nodegroups \
  --cluster-name prod-eks \
  --region us-east-1
```

---

#### Step 2: Review Current Node Group State

```bash
aws eks describe-nodegroup \
  --cluster-name prod-eks \
  --nodegroup-name prod-ng \
  --region us-east-1
```

---

#### Step 3: Trigger Rolling Upgrade

```bash
aws eks update-nodegroup-version \
  --cluster-name prod-eks \
  --nodegroup-name prod-ng \
  --kubernetes-version 1.34 \
  --region us-east-1
```

(Optional) Use new launch template / AMI.

---

#### Step 4: Monitor Progress

```bash
aws eks describe-nodegroup \
  --cluster-name prod-eks \
  --nodegroup-name prod-ng \
  --region us-east-1
```

Wait for:

```
status: UPDATING → ACTIVE
```

---

#### Step 5: Validate Node Rotation

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

---

### A.4 Rollback Strategy

* Create a new node group with previous version
* Shift workloads
* Delete failed node group

⚠️ Node groups cannot be downgraded in-place.

---

## B. Self-Managed Nodes (EKS + ASG)

### Strategy: New ASG + Drain

> **Zero-downtime replacement using immutable infrastructure**

---

### B.1 Preconditions

* New AMI built with target Kubernetes version
* ASG capacity allows temporary scale-up
* PDBs allow eviction
* Backup completed

---

### B.2 Step-by-Step Execution

#### Step 1: Create New Launch Template

* New AMI
* Same instance type, subnets, security groups
* Updated bootstrap configuration

---

#### Step 2: Create New ASG (Parallel)

```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name eks-workers-v2 \
  --launch-template LaunchTemplateName=eks-workers-v2 \
  --min-size 2 --max-size 4 --desired-capacity 3 \
  --vpc-zone-identifier subnet-xxx
```

---

#### Step 3: Wait for New Nodes

```bash
kubectl get nodes
```

Ensure new nodes are:

* `Ready`
* Running target version

---

#### Step 4: Cordon Old Nodes

```bash
kubectl cordon <old-node>
```

---

#### Step 5: Drain Old Nodes

```bash
kubectl drain <old-node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=10m
```

Drain **one node at a time**.

---

#### Step 6: Decommission Old ASG

```bash
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name eks-workers-v1 \
  --force-delete
```

---

### B.3 Rollback Strategy

* Keep old ASG until validation passes
* Re-scale old ASG if rollback required
* Drain and remove new ASG nodes

---

## C. Bare Metal / On-Prem Nodes

### Strategy: Manual Cordon / Drain

> **Highest risk – requires strict discipline**

---

### C.1 Preconditions

* No control plane changes in progress
* PDBs validated
* Backup completed
* Maintenance window approved

---

### C.2 Step-by-Step Execution

#### Step 1: Cordon Node

```bash
kubectl cordon <node-name>
```

Prevents new pods from scheduling.

---

#### Step 2: Drain Node

```bash
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=10m
```

If blocked, investigate:

* PDBs
* Local storage
* StatefulSets

---

#### Step 3: Upgrade Node Software

* OS patches
* Container runtime
* kubelet / kubeadm
* Networking components

---

#### Step 4: Restart kubelet

```bash
systemctl restart kubelet
```

---

#### Step 5: Uncordon Node

```bash
kubectl uncordon <node-name>
```

---

#### Step 6: Validate

```bash
kubectl get nodes
kubectl get pods -A
```

---

### C.3 Rollback Strategy

* Revert packages
* Restore node from snapshot
* Keep node cordoned if unstable

---

## Safety Rules (MANDATORY)

| Rule               | Reason                  |
| ------------------ | ----------------------- |
| One node at a time | Prevent quorum loss     |
| PDBs enforced      | Avoid downtime          |
| Extra capacity     | Avoid Pending pods      |
| Backup completed   | Rollback safety         |
| Monitor events     | Early failure detection |

---

## One-Sentence Executive Summary

> Kubernetes worker node upgrades must use rolling replacement for managed node groups, immutable ASG-based replacement for self-managed nodes, and disciplined manual cordon/drain for bare metal—always respecting PDBs, capacity, and rollback readiness.

---

If you want, I can:

* Add **Jenkins/Terraform automation snippets**
* Convert this into **PDF / SOP format**
* Add **Kafka-specific node upgrade rules**
* Create a **decision tree diagram**

Tell me how you’d like to proceed.
