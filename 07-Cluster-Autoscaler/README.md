Below is a **production-grade, comprehensive explanation** of **what parameters (signals) Cluster Autoscaler monitors**, how it evaluates them, and how those signals influence **scale-up** and **scale-down** decisions. This is aligned with how the upstream Kubernetes Cluster Autoscaler actually works in cloud environments (EKS/GKE/AKS).

---

## Executive Summary

> **Cluster Autoscaler monitors scheduling failures, node utilization, pod constraints, and disruption policies to decide when to add or remove nodes.**

It does **not** watch CPU graphs like HPA. It reasons about **schedulability and safety**.

---

## The Three Categories of Signals

Cluster Autoscaler evaluates signals in **three layers**:

1. **Pod-level signals** (Can pods be scheduled?)
2. **Node-level signals** (Are nodes underutilized and removable?)
3. **Policy & constraint signals** (Is it safe to act?)

All three must align for an action to occur.

---

# 1️⃣ Pod-Level Parameters (Primary Scale-Up Triggers)

These are the **most important inputs**.

---

## 1.1 Pending Pods (Unschedulable Pods)

### What it monitors

* Pods in `Pending` state
* Scheduler reason:

  ```
  Unschedulable
  ```

### Why it matters

> **Pending pods are the only trigger for scale-up.**

If no pods are pending → **no scale-up**, even if nodes are “busy”.

---

## 1.2 Pod Resource Requests (NOT usage)

Cluster Autoscaler looks at:

* `resources.requests.cpu`
* `resources.requests.memory`
* Extended resources (GPUs, hugepages)

❗ It **does NOT** look at actual CPU or memory usage.

Example:

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
```

If no node can satisfy the request → pod is unschedulable → scale-up considered.

---

## 1.3 Pod Scheduling Constraints

Autoscaler evaluates all scheduler constraints, including:

| Constraint                 | Effect                     |
| -------------------------- | -------------------------- |
| nodeSelector               | Limits eligible nodes      |
| nodeAffinity               | Limits eligible nodes      |
| podAffinity / antiAffinity | May block placement        |
| topologySpreadConstraints  | Can force scale-up         |
| tolerations                | Required for tainted nodes |

If **no existing node** matches constraints → autoscaler checks if **new nodes would**.

---

## 1.4 Pod Priority & Preemption

* High-priority pods are evaluated first
* If preemption **could** make room → autoscaler waits
* If preemption **cannot** help → scale-up proceeds

---

## 1.5 Pod Ownership (Important Filter)

Autoscaler **ignores** pods that:

* Are owned by DaemonSets
* Are mirror/static pods
* Are terminating
* Explicitly opt out of autoscaling

This prevents false scale-ups.

---

# 2️⃣ Node-Level Parameters (Scale-Down Decisions)

Scale-down is **more complex and conservative** than scale-up.

---

## 2.1 Node Utilization Thresholds

Autoscaler tracks:

* Sum of **requested** CPU and memory on a node
* Compared against node capacity

Default behavior:

* If node utilization is **below ~50%** (configurable)
* Node becomes a **scale-down candidate**

Again: **requests, not usage**.

---

## 2.2 Node Emptiness

Fastest scale-down path:

* Node has **no non-DaemonSet pods**
* Node is immediately removable

This is why DaemonSets matter.

---

## 2.3 Pod Evictability

Before removing a node, autoscaler checks:

* Can pods be rescheduled elsewhere?
* Do other nodes have enough capacity?
* Do pods have restrictive affinities?

If **any pod cannot be moved**, scale-down is aborted.

---

## 2.4 PodDisruptionBudgets (PDBs)

Autoscaler strictly enforces:

```
allowedDisruptions > 0
```

If any pod on a node is protected by a PDB that blocks eviction:

* Node **cannot** be removed
* Scale-down is skipped

This is why PDB review is mandatory.

---

## 2.5 Local Storage Usage

Pods using:

* `emptyDir`
* `hostPath`

Depending on configuration:

* Node may be excluded from scale-down
* Or require explicit flags

---

# 3️⃣ Policy, Safety & Cloud Provider Parameters

These govern **whether autoscaler is allowed to act**.

---

## 3.1 Node Group Limits

Autoscaler respects:

* Minimum node count
* Maximum node count

Example:

```
min=1, max=10
```

If max reached → no scale-up
If min reached → no scale-down

---

## 3.2 Cloud Provider Signals

Autoscaler queries the cloud provider for:

* Node creation success/failure
* Instance availability
* API errors
* Rate limits

Failures here block scaling.

---

## 3.3 Cooldown Timers

Autoscaler enforces delays to avoid thrashing:

| Timer               | Purpose                 |
| ------------------- | ----------------------- |
| Scale-up cooldown   | Prevent rapid node adds |
| Scale-down cooldown | Prevent rapid deletes   |
| Failure backoff     | Avoid repeated failures |

---

## 3.4 System Pods Protection

By default:

* Nodes with critical system pods (CoreDNS, kube-system) are protected
* Requires explicit flags to override

This prevents cluster instability.

---

## 3.5 Expander Strategy

When multiple node groups exist, autoscaler chooses **which group to scale** using strategies like:

* `least-waste`
* `most-pods`
* `random`
* `price` (cloud-dependent)

This affects **cost and bin-packing efficiency**.

---

# What Cluster Autoscaler Explicitly Does NOT Monitor

This is just as important.

| Signal              | Why              |
| ------------------- | ---------------- |
| Actual CPU usage    | That’s HPA’s job |
| Actual memory usage | That’s HPA’s job |
| Application latency | Out of scope     |
| Request rate        | Out of scope     |
| Custom metrics      | Out of scope     |

Autoscaler is **scheduler-centric**, not performance-centric.

---

## Relationship Summary: HPA vs Cluster Autoscaler

| Concern            | HPA      | Cluster Autoscaler |
| ------------------ | -------- | ------------------ |
| CPU / memory usage | ✅ Yes    | ❌ No               |
| Pending pods       | ❌ No     | ✅ Yes              |
| Node count         | ❌ No     | ✅ Yes              |
| PDB enforcement    | Indirect | Direct             |
| Cost optimization  | ❌ No     | ✅ Yes              |

They are designed to work **together**.

---

## Real-World Example (Condensed)

1. HPA scales app from 5 → 12 pods
2. 4 pods become Pending (no node capacity)
3. Autoscaler detects unschedulable pods
4. Requests 2 new nodes
5. Scheduler places pods
6. Load drops later
7. Pods removed
8. Autoscaler drains and deletes empty nodes

---

## One-Sentence Executive Summary

> **Cluster Autoscaler monitors pending pods, resource requests, scheduling constraints, node utilization, and disruption policies to safely add or remove nodes while preserving application availability.**

---

## Practical Takeaways for You

* Always set **accurate resource requests**
* Validate **PDBs before upgrades**
* Do not expect autoscaler to fix bad affinities
* Never confuse autoscaler with HPA
* Validate autoscaler behavior in **EKS, not KIND**

---

If you want, I can next:

* Walk through **autoscaler logs line by line**
* Compare **Cluster Autoscaler vs Karpenter**
* Provide **autoscaler tuning recommendations for EKS**
* Tie autoscaler decisions to **upgrade failures you’ve seen**

Just tell me.
