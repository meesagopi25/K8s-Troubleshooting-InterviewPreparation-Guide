

---

## 1️⃣ How do you roll back a bad deployment?

### **Problem**

A new deployment version is unhealthy (pods failing, errors in logs, readiness failing, etc.).

---

### **Steps to Roll Back**

#### **1. View deployment rollout history**

```bash
kubectl rollout history deployment/myapp
```

This shows all previous revisions of the deployment.

---

#### **2. Roll back to the previous stable version**

```bash
kubectl rollout undo deployment/myapp
```

This immediately reverts to the last known good revision.

---

#### **3. Roll back to a specific revision (if needed)**

```bash
kubectl rollout undo deployment/myapp --to-revision=5
```

Use this when you know exactly which version was stable.

---

#### **4. Verify rollback status**

```bash
kubectl rollout status deployment/myapp
```

---

#### **5. Validate application health**

```bash
kubectl get pods
kubectl logs <pod-name>
```

Ensure all pods are running and serving traffic correctly.

---

### **Key Points**

* Rollbacks are **fast and safe** with Deployments.
* Old ReplicaSets are retained for rollback unless manually cleaned.
* Always verify pod readiness and logs after rollback.

---

Below is **Point 2**, renumbered and formatted consistently for direct inclusion in your `README.md`.

---

## 2️⃣ Pod Stuck Waiting for PVC to Bind

### Problem

A Pod remains in `Pending` state because its **PersistentVolumeClaim (PVC)** is not bound to a **PersistentVolume (PV)**.

### How to Investigate

```bash
kubectl describe pvc <pvc-name>
```

Check the following:

* **Status** (e.g., `Pending`)
* **Events** section for binding or provisioning errors

### Common Causes

* No matching **PersistentVolume (PV)** exists and **dynamic provisioning** is not enabled
* Incorrect or non-existent `storageClassName`
* Mismatch in **accessModes** (e.g., `ReadWriteOnce` vs `ReadWriteMany`)
* Requested storage size exceeds available PV capacity
* PV has `nodeAffinity` that does not match the node where the Pod is scheduled

### How to Fix

* Create an appropriate **PersistentVolume**, or enable/fix **dynamic provisioning**
* Correct the `storageClassName` in the PVC
* Align **accessModes** between PVC and PV
* Adjust the requested PVC size to fit available PVs
* Ensure PV `nodeAffinity` matches the target node

---

Your README numbering is now consistent for **2️⃣ and 3️⃣**. If you want, I can review the entire document for structure, flow, and troubleshooting completeness.

## 3️⃣ StatefulSet Pod Fails to Attach the Same Volume on a New Node

### Problem

A StatefulSet Pod fails to start on a new node because the previously attached volume cannot be reattached.

### Common Causes

* The volume uses **ReadWriteOnce (RWO)** and is still attached to the old node
* The underlying cloud disk has not fully detached yet

  * This can happen during node failure or abrupt termination
* The **PersistentVolume (PV)** has `nodeAffinity` that does not match the new node
* Certain storage backends allow a volume to be mounted by **only one node at a time**

### How to Investigate

```bash
kubectl describe pod <pod-name>
kubectl describe pv <pv-name>
```

Check for:

* Volume attachment errors in Pod events
* `nodeAffinity` constraints on the PV
* Cloud provider disk attachment state

### How to Fix

* Ensure the failed or old node is properly removed from the cluster
* Wait for the volume to detach automatically, or detach it manually via the cloud provider
* Update or recreate the PV if `nodeAffinity` is incorrect
* Use a storage backend that supports multi-node access if required

---

Below is **Point 4**, formatted consistently and ready to append to your `README.md`.

---

## 4️⃣ Difference Between `emptyDir`, `hostPath`, and `PVC`

### Overview

Kubernetes provides multiple volume types, each suited for different storage requirements such as temporary data, node-specific access, or durable persistence.

### `emptyDir`

* **Ephemeral storage** tied to the Pod lifecycle
* Created when the Pod starts and deleted when the Pod is removed
* Data is lost if the Pod is deleted or recreated
* Commonly used for:

  * Temporary files
  * Caches
  * Sharing data between containers in the same Pod

### `hostPath`

* Mounts a directory or file from the **node’s filesystem** into the Pod
* Strongly coupled to a **specific node**
* Can introduce **security and stability risks** if misused
* Commonly used for:

  * Accessing node-level resources
  * Debugging or system-level workloads
* Generally **not recommended** for portable or production workloads

### `PersistentVolumeClaim (PVC)`

* An abstraction over **persistent storage**
* Backed by **PersistentVolumes (PVs)** and **StorageClasses**
* Independent of Pod lifecycle
* Supports dynamic provisioning and storage policies
* Designed for **durable storage** and **portability across nodes** (subject to storage backend capabilities)

### Summary Comparison

| Volume Type | Persistence | Node Dependency | Typical Use Case  |
| ----------- | ----------- | --------------- | ----------------- |
| `emptyDir`  | No          | No              | Temporary data    |
| `hostPath`  | Yes*        | Yes             | Node-level access |
| `PVC`       | Yes         | No*             | Application data  |

* Depends on configuration and storage backend.

---

Below is **Point 5**, formatted consistently and ready to append to your `README.md`.

---

## 5️⃣ Updated ConfigMap but Application Does Not See the New Values

### Problem

A ConfigMap is updated, but the running application continues to use the old configuration values.

### Common Causes

* **ConfigMap mounted as environment variables**

  * Environment variables are read **only at container startup**
  * Updates to the ConfigMap are **not reflected** in running Pods
  * Requires a Pod restart or Deployment rollout

* **ConfigMap mounted as a volume**

  * Files are updated automatically (with a short delay)
  * The application must:

    * Re-read the files periodically, or
    * Support configuration reload (e.g., SIGHUP, hot reload)

### Recommended Practices

* Use a **checksum/config annotation** on the Pod template:

  * Any change to the ConfigMap changes the checksum
  * This triggers a **RollingUpdate**
  * Pods restart and pick up the new configuration

#### Example Annotation Pattern

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: <hash-of-configmap>
```

### How to Fix

* Restart Pods manually if ConfigMaps are used as environment variables
* Implement config reload logic in the application when using volume mounts
* Use checksum-based annotations to automate safe rolling updates

---

Below is **Point 6**, formatted consistently and ready to append to your `README.md`.

---

## 6️⃣ How to Safely Inject Sensitive Information into a Pod

### Overview

Sensitive data such as passwords, API keys, and tokens should never be hardcoded into images or manifests. Kubernetes provides **Secrets** to manage this securely.

### Recommended Approach

#### Use Kubernetes Secrets

Create a Secret:

```bash
kubectl create secret generic mysecret \
  --from-literal=password=...
```

Inject the Secret into a Pod using:

* **Environment variables**, or
* **Volume mounts** (preferred for rotation and file-based access)

### Security Best Practices

* Restrict access to Secrets using **RBAC**

  * Only authorized users and service accounts should be able to read them
* Enable **encryption at rest** for Secrets in the cluster datastore (etcd)
* Avoid exposing Secrets via logs or debug output

### Production-Grade Patterns

For enterprise and production environments:

* Use **external secret managers**, such as:

  * HashiCorp Vault
  * AWS Secrets Manager
  * Azure Key Vault
  * Google Secret Manager
* Use an **operator or controller** (e.g., External Secrets Operator) to:

  * Sync external secrets into Kubernetes Secrets
  * Handle rotation and lifecycle management automatically

### Summary

* Kubernetes Secrets are the baseline solution
* RBAC and encryption are mandatory for security
* External secret stores are recommended for large-scale and regulated environments

---

If you’d like, I can add **examples comparing env var vs volume-based secret injection** or align this with Kubernetes security best practices and certifications.

Below is **Point 7**, formatted consistently and ready to append to your `README.md`.

---

## 7️⃣ User Gets `Forbidden` When Using `kubectl`

### Problem

A user or service account receives a `Forbidden` error when attempting to perform an action using `kubectl`.

### How to Investigate

#### Identify the Active User or Service Account

```bash
kubectl config view --minify
```

Confirm which **user** or **service account (SA)** is being used for the request.

#### Verify Permissions

```bash
kubectl auth can-i get pods --as <user> -n <namespace>
```

This command checks whether the specified user is authorized to perform the action.

### Common Causes

* Missing or incorrect **Role** or **ClusterRole**
* Missing or incorrect **RoleBinding** or **ClusterRoleBinding**
* Permissions granted in the wrong namespace
* Using a different user or service account than expected

### How to Fix

Create or update the appropriate RBAC objects.

#### Example: RoleBinding

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-reader-binding
  namespace: <namespace>
subjects:
  - kind: User
    name: <user>
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: <role>
  apiGroup: rbac.authorization.k8s.io
```

### Best Practices

* Prefer **least-privilege access**
* Use **ClusterRoleBindings** only when cluster-wide access is required
* Regularly audit RBAC permissions

---

If you want, I can add a **quick RBAC troubleshooting checklist** or a **mapping of common kubectl errors to RBAC misconfigurations** for your README.

Below is **Point 8**, formatted consistently and ready to append to your `README.md`.

---

## 8️⃣ How to Restrict External Access to a Deployment

### Overview

Restricting external access is critical for securing internal services and reducing the attack surface of applications running in Kubernetes.

### Recommended Approaches

#### Use an Internal Service Type

* Expose the application using a **ClusterIP** Service only
* Avoid using:

  * `NodePort`
  * `LoadBalancer`
* This ensures the service is accessible **only within the cluster**

#### Control Access via Ingress

* Use **Ingress** with:

  * Specific **host-based** and **path-based** routing rules
  * Authentication mechanisms if required (OAuth, basic auth, mTLS)
* Avoid wildcard hosts unless explicitly needed

#### Apply NetworkPolicies

Use **NetworkPolicies** to control Pod-to-Pod traffic:

* Allow traffic only from:

  * Specific namespaces
  * Specific Pods (via labels)
* Deny all other ingress traffic by default

### Cloud and Infrastructure-Level Controls

In cloud environments, add additional protection using:

* **Web Application Firewalls (WAF)**
* **Firewalls**
* **Security Groups**
* **Private endpoints or internal load balancers**

### Defense-in-Depth Summary

* ClusterIP limits exposure at the Service level
* Ingress controls and authentication manage HTTP access
* NetworkPolicies restrict network-level reachability
* Cloud-level controls provide an additional security boundary

---

If you want, I can add a **reference NetworkPolicy example** or a **security checklist** to strengthen this section further.

Below is **Point 9**, formatted consistently and ready to append to your `README.md`.

---

## 9️⃣ Ingress Configured but Returns `404 Not Found`

### Problem

An Ingress resource exists, but requests to the application return `404 Not Found`.

### Common Causes

#### Ingress Controller Issues

* Ingress controller is **not installed** or not running
* Incorrect or missing **IngressClass**

  * On newer clusters, `ingressClassName` must be explicitly specified
    (e.g., `nginx`)

#### Hostname Mismatch

* The request hostname does not match the Ingress rule

  * Example:

    * Ingress expects: `app.example.com`
    * Browser request uses: `http://<IP>`

#### Path Configuration Errors

* Path does not match the request URL
* Incorrect `pathType` (`Prefix`, `Exact`, `ImplementationSpecific`)

#### Service or Port Misconfiguration

* Ingress points to the **wrong Service**
* Incorrect **Service port** is referenced in the Ingress

#### TLS Misconfiguration

* TLS host in the Ingress does not match the request hostname
* Some Ingress controllers return `404` when TLS host validation fails

### How to Investigate

```bash
kubectl describe ingress <ingress-name>
kubectl get ingressclass
kubectl get svc
```

Check:

* Assigned `ingressClassName`
* Host and path rules
* Backend Service name and port
* TLS configuration

### How to Fix

* Install and verify the correct Ingress controller
* Set the proper `ingressClassName`
* Ensure request hostname matches the Ingress host
* Correct path and `pathType`
* Verify Service name and exposed port
* Fix TLS host and certificate configuration

---

If you’d like, I can add a **sample working Ingress manifest** or a **step-by-step Ingress debugging flow** to complete this section.

Below is the content modified and formatted as **Point 10**, consistent with the previous sections and ready to append to your `README.md`.

---

## 🔟 How to Route Only 5% of Traffic to a New Version (Canary Deployment)

### Overview

Canary deployments allow you to release a new version of an application to a small percentage of users while monitoring its behavior before full rollout.

### Approach 1: Ingress Controller with Traffic Weights

Use an Ingress controller that supports weighted routing, such as:

* **NGINX Ingress**
* **Istio Ingress Gateway**
* **Traefik**

#### Key Idea

* Define two backends:

  * **v1** (stable version) → 95%
  * **v2** (canary version) → 5%
* Traffic is split based on configured weights

### Approach 2: Service Mesh (Istio VirtualService)

Using Istio, traffic splitting is defined declaratively via a `VirtualService`.

#### Example: Istio Canary Routing

```yaml
http:
  - route:
      - destination:
          host: myapp
          subset: v1
        weight: 95
      - destination:
          host: myapp
          subset: v2
        weight: 5
```

### Monitoring and Rollout Strategy

* Monitor key metrics:

  * Error rate
  * Latency
  * Resource usage
* Gradually increase traffic to the new version if metrics remain healthy
* Roll back immediately if anomalies are detected

### Best Practices

* Use **labels and subsets** consistently for versions
* Automate traffic changes via CI/CD pipelines
* Combine canary releases with **observability tooling** (Prometheus, Grafana, alerts)

---

If you want, I can also add a **non–service-mesh canary example using plain Kubernetes Services** or a **comparison of canary vs blue-green deployments** for completeness.

Below is **Point 11**, formatted consistently and ready to append to your `README.md`.

---

## 1️⃣1️⃣ Why `kubectl auth can-i --as default` Fails Without RBAC

### Problem

Running `kubectl auth can-i` with `--as default` (or the default ServiceAccount) returns `no`, even though the ServiceAccount exists.

### Key Reason: Kubernetes Uses a Default-Deny Model

Kubernetes authorization follows a **deny-by-default** security model:

* If no RBAC rule explicitly allows an action, it is denied
* There are **no implicit permissions** for users or ServiceAccounts

So, without RBAC bindings, authorization always fails.

---

### The `default` ServiceAccount Has No Permissions

Every namespace automatically includes a ServiceAccount named `default`, but:

* It is created **without any Role or ClusterRole bindings**
* Its purpose is to provide:

  * An identity for Pods
  * Authentication via a mounted token

It does **not** grant authorization on its own.

Correct identity for the default ServiceAccount:

```text
system:serviceaccount:default:default
```

Authorization check example:

```bash
kubectl auth can-i get pods \
  --as system:serviceaccount:default:default \
  -n default
```

This returns `no` unless RBAC rules are configured.

---

### `--as default` vs ServiceAccount Identity

Using:

```bash
kubectl auth can-i get pods --as default
```

Means:

* Kubernetes treats `default` as a **user**
* No such user exists by default

ServiceAccounts must always be referenced as:

```text
system:serviceaccount:<namespace>:<name>
```

---

### Authentication vs Authorization (Critical Distinction)

| Stage          | Description                                    |
| -------------- | ---------------------------------------------- |
| Authentication | Verifies *who* you are (token, cert, identity) |
| Authorization  | Verifies *what* you are allowed to do (RBAC)   |

For the `default` ServiceAccount:

* ✅ Authentication succeeds
* ❌ Authorization fails (no RBAC permissions)

---

### How Permissions Are Granted

The **only way** to allow actions is through RBAC:

* `Role` or `ClusterRole`
* `RoleBinding` or `ClusterRoleBinding`

Without these, `kubectl auth can-i` will always return `no`.

---

### Why Kubernetes Works This Way

This design:

* Prevents accidental privilege escalation
* Reduces blast radius if a Pod is compromised
* Enforces **least-privilege security**

Permissions must be **explicit, scoped, and auditable**.

---

### Summary

| Question                                          | Answer                                     |
| ------------------------------------------------- | ------------------------------------------ |
| Why does `kubectl auth can-i --as default` fail?  | No RBAC permissions exist                  |
| Is `default` a real user?                         | No                                         |
| Does the default ServiceAccount have permissions? | No                                         |
| Is this expected behavior?                        | Yes, by design                             |
| How to fix it?                                    | Create a RoleBinding or ClusterRoleBinding |

---

Below is a **clean README-ready addition**, followed by a **decision tree** and **interview-style answers**, exactly as requested.

---

## 1️⃣1️⃣ Node Is `NotReady` — How to Troubleshoot

### Problem

A Kubernetes node is marked as **`NotReady`**, meaning the control plane cannot reliably schedule or run Pods on it.

```bash
kubectl get nodes
```

Example:

```text
NAME            STATUS     ROLES    AGE   VERSION
worker-node-1   NotReady   <none>   12d   v1.29.2
```

---

### Step 1: Describe the Node and Inspect Conditions

```bash
kubectl describe node <node-name>
```

Focus on the **Conditions** section.

Example:

```text
Conditions:
  Type               Status   Reason              Message
  Ready              False    KubeletNotReady     runtime network not ready
  DiskPressure       True     DiskPressure        node has disk pressure
  MemoryPressure     False    SufficientMemory
  NetworkUnavailable False    CalicoIsUp
```

#### Common Conditions Explained

| Condition                 | Meaning                   |
| ------------------------- | ------------------------- |
| `DiskPressure=True`       | Node disk is nearly full  |
| `MemoryPressure=True`     | Node is low on memory     |
| `PIDPressure=True`        | Too many processes        |
| `NetworkUnavailable=True` | CNI/networking broken     |
| `Ready=False`             | Node cannot run workloads |

> **Most common real-world cause:** DiskPressure due to full disk.

---

### Step 2: Check Kubelet on the Node

SSH into the node:

```bash
ssh <node>
```

Check kubelet status:

```bash
sudo systemctl status kubelet
```

View logs:

```bash
sudo journalctl -u kubelet -n 100
```

Example error:

```text
eviction manager: nodefs.available is below eviction threshold
```

➡️ Indicates disk pressure.

---

### Step 3: Check Container Runtime

If the runtime is down, kubelet cannot function.

For containerd:

```bash
sudo systemctl status containerd
```

For Docker (older clusters):

```bash
sudo systemctl status docker
```

If runtime is stopped or crashing, the node will remain `NotReady`.

---

### Step 4: Check CNI Plugin Health

Networking issues can mark the node `NotReady`.

```bash
kubectl get pods -n kube-system
```

Check CNI pods:

```bash
kubectl get pods -n kube-system | grep -E "calico|flannel|cilium"
```

Example:

```text
calico-node-abc   CrashLoopBackOff
```

➡️ `NetworkUnavailable=True`
➡️ Node networking is broken.

---

### Step 5: Verify Disk Space (Very Common Root Cause)

```bash
df -h
```

Example:

```text
Filesystem      Size  Used Avail Use%
/dev/sda1        50G   49G   1G   98%
```

Why this matters:

* kubelet enforces **eviction thresholds**
* When disk is full:

  * Pods are evicted
  * Node becomes `NotReady`

#### Quick Fixes

```bash
crictl rmi --prune
sudo journalctl --vacuum-time=3d
```

Or expand the disk (cloud environments).

---

### Summary of Common Causes

| Symptom                   | Likely Cause            | Fix                   |
| ------------------------- | ----------------------- | --------------------- |
| `DiskPressure=True`       | Disk full               | Clean / expand disk   |
| `KubeletNotReady`         | kubelet crashed         | Restart kubelet       |
| Runtime down              | containerd/docker issue | Restart runtime       |
| `NetworkUnavailable=True` | CNI failure             | Fix CNI               |
| Node unreachable          | OS / infra issue        | Reboot / replace node |

---

## Decision Tree: Node `NotReady`

```
Node is NotReady
        |
        v
kubectl describe node
        |
        ├── DiskPressure=True?
        |       └── Yes → Check df -h → Clean disk / expand volume
        |
        ├── MemoryPressure=True?
        |       └── Yes → Check memory → Reduce load / scale
        |
        ├── NetworkUnavailable=True?
        |       └── Yes → Check CNI pods → Fix Calico/Flannel/Cilium
        |
        ├── KubeletNotReady?
        |       └── Yes → Check kubelet logs → Restart kubelet
        |
        ├── Container runtime down?
        |       └── Yes → Restart containerd/docker
        |
        └── Node unreachable?
                └── Infra issue → Reboot / replace node
```

---

## Interview-Style Answers (High-Quality)

### Q1: What does a `NotReady` node indicate?

**Answer:**
It means kubelet on the node cannot communicate properly with the control plane or cannot meet required health conditions, so Kubernetes stops scheduling workloads on it.

---

### Q2: What is the first command you run?

**Answer:**
`kubectl describe node <node>` to inspect node conditions such as DiskPressure, MemoryPressure, and NetworkUnavailable.

---

### Q3: What is the most common cause of `NotReady` in production?

**Answer:**
Disk exhaustion. When disk usage crosses kubelet eviction thresholds, the node is marked `NotReady`.

---

### Q4: How does disk pressure affect node readiness?

**Answer:**
Kubelet evicts Pods and eventually marks the node `NotReady` to prevent further scheduling when available disk falls below thresholds.

---

### Q5: Can CNI issues cause `NotReady`?

**Answer:**
Yes. If the CNI plugin fails, `NetworkUnavailable=True`, and the node cannot participate in cluster networking.

---

### Q6: Why does a container runtime failure cause `NotReady`?

**Answer:**
Kubelet depends on the container runtime to manage Pods. If the runtime is down, kubelet cannot function.

---

### Q7: How do you fix a permanently broken node?

**Answer:**
Cordon and drain the node, then delete or replace it:

```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets
kubectl delete node <node>
```

---

### One-Line Interview Summary

> “For a `NotReady` node, I start with `kubectl describe node`, then check disk, kubelet, container runtime, and CNI — disk pressure is the most common cause.”

---

Below is **clean, copy-paste–ready content** to append to your **`README.md`**, formatted as **two interview questions**, numbered **12️⃣ and 13️⃣**, combining the **last two explanations** in a concise but **technically strong** way.

---

## 1️⃣2️⃣ ETCD Is Unhealthy. What Do You Do?

### Explanation

**etcd is the backing store for all Kubernetes cluster state.**
If etcd becomes unhealthy, the Kubernetes API server cannot reliably read or write state, causing the cluster to become slow, partially unavailable, or completely down.

---

### Step-by-Step Troubleshooting

#### 1️⃣ Check etcd cluster health

```bash
etcdctl endpoint health
```

* Confirms whether etcd can commit writes
* `context deadline exceeded` usually indicates disk or quorum issues

---

#### 2️⃣ Check member status

```bash
etcdctl member list
```

Look for:

* Unhealthy members
* Missing peers
* Repeated leader changes

---

#### 3️⃣ Check system resources (MOST COMMON ROOT CAUSE)

* **CPU / Memory pressure**
* **Disk latency** (etcd is extremely sensitive)
* **Disk full**, especially under `/var/lib/etcd`

```bash
df -h /var/lib/etcd
iostat -x
```

> In real incidents, etcd issues are often caused by slow or full disks, not Kubernetes bugs.

---

#### 4️⃣ Verify certificates and configuration

* etcd uses **mutual TLS**
* Expired or mismatched certificates prevent members from communicating

```bash
openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -dates
```

---

#### 5️⃣ Check etcd logs

```bash
journalctl -u etcd -n 100
```

Common error patterns:

* `apply entries took too long`
* `timeout`
* `leader changed`

---

### Disaster Recovery

#### Take regular snapshots (Best Practice)

```bash
etcdctl snapshot save backup.db
```

#### Restore from snapshot (Worst case)

```bash
etcdctl snapshot restore backup.db --data-dir /var/lib/etcd
```

This recreates the etcd cluster from a known-good state.

---

### Managed Kubernetes Note (AKS / EKS / GKE)

* etcd is **fully managed**
* You cannot access or repair it directly
* But you **must still understand the failure patterns and symptoms**

---

### Interview-Ready Summary

> “When etcd is unhealthy, I first check endpoint health, then system resources like disk latency and capacity, followed by certificate validity. Disk issues are the most common root cause. Recovery relies on regular etcd snapshots.”

---

## 1️⃣3️⃣ If We Have a Quorum, How Is ETCD Data Synced Across All Members?

### Explanation

**etcd uses the Raft consensus algorithm** to keep data consistent across all members.

> Every write goes through a **leader**, is replicated to **followers**, and is committed **only after a majority (quorum) acknowledges it**.

---

### Example: 3-Node etcd Cluster

```
etcd-1 (Leader)
etcd-2 (Follower)
etcd-3 (Follower)
```

Quorum = **2 out of 3**

---

### Step-by-Step: How a Write Is Synced

1️⃣ API Server sends a write request to the **etcd leader**
2️⃣ Leader appends the entry to its **Write-Ahead Log (WAL)**
3️⃣ Leader sends the entry to followers
4️⃣ Followers write the entry to their WAL and acknowledge
5️⃣ Once **quorum acknowledges**, the entry is **committed**
6️⃣ All members apply the committed entry to their local store

At this point:

> **All healthy etcd members have the same data**

---

### What If a Node Goes Down?

* As long as **quorum exists**, writes continue
* The failed node stops receiving updates
* When it comes back:

  * It catches up using missing logs or a snapshot

---

### What If the Leader Goes Down?

* Followers detect missing heartbeats
* A **new leader is elected**
* Only **committed data survives**
* Cluster continues safely

---

### Why Quorum Is Mandatory

Quorum prevents **split-brain**:

* Only the majority side can accept writes
* Minority partitions become read-only

---

### Where the Data Lives

Each member stores replicated data locally:

```text
/var/lib/etcd/
 ├── wal/
 ├── snap/
```

All nodes store the **same logical state**, synchronized via Raft.

---

### Interview-Ready Summary

> “etcd synchronizes data using the Raft consensus algorithm, where a leader serializes writes and commits them only after a majority of members acknowledge, ensuring strong consistency across the cluster.”

---

### One-Line Takeaway

> **Quorum ensures safety; Raft ensures synchronization.**

---

Below is a **clean, copy-paste ready README.md section**, written in **documentation style**, converting the KIND-specific HPA demo into a reusable guide.

---

Below is the **same README section**, simply **renumbered and renamed as Question 14**, ready to paste into your document.

---

## 1️⃣4️⃣ KIND-Specific HPA Demo (CPU-Based Autoscaling)

This section demonstrates **Horizontal Pod Autoscaler (HPA)** behavior in a **KIND (Kubernetes in Docker)** cluster and highlights the **mandatory requirement of metrics-server**.

---

### Objective

* Install and configure `metrics-server` in KIND
* Deploy a CPU-bound application
* Configure HPA based on CPU utilization
* Generate load and observe automatic scaling
* Understand why HPA may fail without metrics

---

## Prerequisites

* KIND cluster running
* `kubectl` configured to access the cluster

Verify cluster access:

```bash
kubectl get nodes
```

---

## Step 1: Install metrics-server (Mandatory for KIND)

HPA depends on the `metrics.k8s.io` API, which is provided by **metrics-server**.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## Step 2: Patch metrics-server for KIND

KIND uses self-signed kubelet certificates, so metrics-server must be patched.

```bash
kubectl -n kube-system edit deployment metrics-server
```

Add the following under `args:`:

```yaml
- --kubelet-insecure-tls
- --kubelet-preferred-address-types=InternalIP
```

Save and exit.

---

## Step 3: Verify metrics-server

```bash
kubectl get apiservices | grep metrics
```

Expected output:

```text
v1beta1.metrics.k8s.io   kube-system/metrics-server   True
```

Verify metrics availability:

```bash
kubectl top nodes
kubectl top pods
```

If these commands work, HPA can function correctly.

---

## Step 4: Deploy a CPU-Bound Application

Create a simple nginx deployment:

```bash
kubectl create deployment hpa-demo --image=nginx
```

Patch the deployment with **CPU requests and limits** (critical for HPA):

```bash
kubectl patch deployment hpa-demo -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "image": "nginx",
          "resources": {
            "requests": {
              "cpu": "100m"
            },
            "limits": {
              "cpu": "500m"
            }
          }
        }]
      }
    }
  }
}'
```

---

## Step 5: Create the HPA

Configure HPA to scale when CPU exceeds **50% of requested CPU**:

```bash
kubectl autoscale deployment hpa-demo \
  --cpu-percent=50 \
  --min=1 \
  --max=5
```

Check HPA status:

```bash
kubectl get hpa
```

---

## Step 6: Generate CPU Load

Start a load generator pod:

```bash
kubectl run -i --tty load-generator \
  --image=busybox \
  --restart=Never \
  -- /bin/sh
```

Inside the pod, run:

```sh
while true; do wget -q -O- http://hpa-demo; done
```

This continuously hits the nginx service and increases CPU usage.

---

## Step 7: Observe Autoscaling

In another terminal:

```bash
kubectl get hpa -w
```

You should observe CPU utilization exceeding the target and replicas increasing:

```text
TARGETS   75%/50%
```

Verify pod scaling:

```bash
kubectl get pods
```

---

## Step 8: Scale Down After Load Stops

Stop the load generator:

```sh
Ctrl + C
exit
```

Delete the pod:

```bash
kubectl delete pod load-generator
```

Pods will scale down **after the HPA stabilization window** (typically ~5 minutes).

---

## Step 9: Cleanup

```bash
kubectl delete deployment hpa-demo
kubectl delete hpa hpa-demo
```

---

## Key Takeaways

* HPA **requires metrics-server**
* HPA scales based on **CPU utilization relative to requests**, not limits
* KIND requires special flags for metrics-server due to self-signed certificates
* Scaling is **not instant** due to stabilization windows

---

## Interview-Ready Summary

> “In KIND clusters, HPA works only after installing and patching metrics-server. Once metrics are available, HPA scales pods based on CPU utilization as a percentage of requested CPU.”

---

## One-Line Conclusion

> **No metrics-server = no HPA, regardless of CPU usage.**

---

If you want the numbering aligned across your **entire README**, I can reindex everything cleanly in one pass.
