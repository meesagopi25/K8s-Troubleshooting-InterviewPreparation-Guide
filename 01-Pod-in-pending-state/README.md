---

# 🧪 Kubernetes Troubleshooting Lab

## **Understanding & Fixing Pods Stuck in Pending State**

This guide provides **hands-on, practical troubleshooting scenarios** covering every major reason a Kubernetes Pod may be stuck in the **Pending** phase.
It is designed for **interview preparation**, **DevOps training**, and **real-world debugging practice**.

Each scenario includes:

* What the issue is
* How to reproduce it
* How to troubleshoot it
* How to fix it

Works on:

* Minikube
* KIND
* OpenShift Local
* OpenShift Sandbox
* Any Kubernetes cluster

---

# 🧩 Prerequisites

Ensure you can run:

```bash
kubectl get nodes
kubectl apply -f file.yaml
kubectl describe pod <pod>
kubectl describe node <node>
```

---

# 📘 Table of Contents

1. [Insufficient CPU](#1️⃣-insufficient-cpu)
2. [Insufficient Memory](#2️⃣-insufficient-memory)
3. [Node Taints](#3️⃣-node-taints)
4. [Unbound PVC](#4️⃣-unbound-pvc)
5. [Node Selector Mismatch](#5️⃣-node-selector-mismatch)
6. [Anti-Affinity Rules](#6️⃣-anti-affinity-rules)
7. [SCC / PSP Security Restrictions](#7️⃣-securitycontextconstraints--psp-failure-openshift)
8. [ResourceQuota Violations](#8️⃣-resourcequota-violations)
9. [GPU Requests Not Allowed](#9️⃣-gpu-requests-not-allowed)
10. [Ephemeral Storage Violations](#🔟-ephemeral-storage-violations)
11. [Common Troubleshooting Commands](#1️⃣1️⃣-common-troubleshooting-commands)

---

# 1️⃣ Insufficient CPU

### ❌ Problem

Pod requests more CPU than allowed in the namespace quota.

### YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-hog
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: "4000m"
      limits:
        cpu: "20"
```

### Create the pod:

```bash
oc apply -f cpu-hog.yml
```

### Expected error:

```
pods "cpu-hog" is forbidden: exceeded quota: compute-deploy,
requested: requests.cpu=4, used: 200m, limited: 3
```

### ✔ Fix

Lower the CPU request.

---

# 2️⃣ Insufficient Memory

### YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "30Gi"
```

### Error:

```
Invalid value: "30Gi": must be <= memory limit of 1000Mi
```

### 🔍 Troubleshooting LimitRange

```bash
oc get limits -n mg1982-dev
oc describe limits resource-limits
```

Output shows:

| Field           | Value  |
| --------------- | ------ |
| Default Request | 64Mi   |
| Default Limit   | 1000Mi |
| Max             | none   |

### Why it fails

* Even if Max is empty, the **Default Limit = 1000Mi**
* Kubernetes enforces:
  **request.memory ≤ limit.memory**
* Your request: **30Gi**, default limit: **1Gi**

### ✔ NOT a ResourceQuota issue → It’s a LimitRange issue

---

### ⭐ How to Fix

#### **OPTION 1 — Set your own limit ≥ request (NOT allowed in OpenShift Sandbox)**

```yaml
resources:
  requests:
    memory: 30Gi
  limits:
    memory: 30Gi
```

Sandbox blocks this → cluster-wide 1Gi policy.

#### **OPTION 2 — Request less memory (recommended)**

```yaml
resources:
  requests:
    memory: 512Mi
  limits:
    memory: 1Gi
```

---

# 3️⃣ Node Taints

### Add a taint:

```bash
kubectl taint nodes <node> dedicated=backend:NoSchedule
```

### Pod that **fails**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fail-on-taint
spec:
  containers:
  - name: app
    image: nginx
```

### Error:

```
node(s) had taint {dedicated=backend:NoSchedule}, that the pod didn't tolerate
```

### ✔ Fix — Add toleration

```yaml
tolerations:
- key: "dedicated"
  operator: "Equal"
  value: "backend"
  effect: "NoSchedule"
```

---

## ⭐ Pod that **schedules** on tainted node (toleration + nodeSelector)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: force-nodeselector
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "backend"
    effect: "NoSchedule"

  nodeSelector:
    kubernetes.io/hostname: kafka-cluster-worker2

  containers:
  - name: nginx
    image: nginx
```

---

## ⭐ Pod that forces scheduling using NodeAffinity + Toleration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: force-affinity
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "backend"
    effect: "NoSchedule"

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - kafka-cluster-worker2

  containers:
  - name: nginx
    image: nginx
```

---

## ⭐ Pods that FAIL (expected Pending state)

### Without toleration:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fail-no-toleration
spec:
  nodeSelector:
    kubernetes.io/hostname: kafka-cluster-worker2
  containers:
  - name: nginx
    image: nginx
```

### Without toleration (affinity version):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fail-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - kafka-cluster-worker2
  containers:
  - name: nginx
    image: nginx
```

---

# 📊 Summary Comparison

| Pod Type           | Has Toleration? | Forced Node Scheduling? | Result    |
| ------------------ | --------------- | ----------------------- | --------- |
| force-nodeselector | Yes             | Yes                     | Schedules |
| force-affinity     | Yes             | Yes                     | Schedules |
| fail-no-toleration | No              | Yes                     | ❌ Pending |
| fail-affinity      | No              | Yes                     | ❌ Pending |

---

# 4️⃣ Unbound PVC

### Unbindable PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bad-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
  storageClassName: does-not-exist
```

### Pod that fails

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: busy
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: bad-pvc
```

### Error:

```
persistentvolumeclaim "bad-pvc" is not bound
```

---

# 5️⃣ Node Selector Mismatch

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-selector-fail
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: app
    image: nginx
```

Error:

```
0 nodes match pod's node selector
```

---

# 6️⃣ Anti-Affinity Rules

### Impossible Anti-Affinity Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: anti-affinity-fail
  labels:
    app: test
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: test
        topologyKey: kubernetes.io/hostname
  containers:
  - name: app
    image: nginx
```

---

# 7️⃣ SecurityContextConstraints / PSP Failure (OpenShift)

Privileged container:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-denied
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      privileged: true
```

Error:

```
pod is not allowed to use SecurityContextConstraints "privileged"
```

Fix:

```bash
oc adm policy add-scc-to-user privileged -z default
```

---

# 8️⃣ ResourceQuota Violations

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: quota-memory-fail
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "40Gi"
```

---

# 9️⃣ GPU Requests Not Allowed

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-fail
spec:
  containers:
  - name: cuda
    image: nvidia/cuda
    resources:
      requests:
        nvidia.com/gpu: 1
```

Error:

```
exceeded quota: requests.nvidia.com/gpu=1, limited: 0
```

---

# 🔟 Ephemeral Storage Violations

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-fail
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        ephemeral-storage: "20Gi"
```

---

# 1️⃣1️⃣ Common Troubleshooting Commands

```bash
kubectl describe pod <pod>
kubectl describe node <node>

kubectl top pods
kubectl top nodes

kubectl get pvc
kubectl describe pvc <pvc>
```

---

# 🎓 Conclusion

This guide provides hands-on examples and troubleshooting practice for all major causes of Pods stuck in **Pending**, including:

* Resource shortages
* Taints
* PVC issues
* Node selector mismatch
* Affinity constraints
* Security restrictions
* ResourceQuota & LimitRange violations
* GPU & ephemeral storage limits

Use this as a **training and interview preparation reference** to master practical Kubernetes debugging.

---
