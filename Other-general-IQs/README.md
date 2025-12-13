

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

## Pod Stuck Waiting for PVC to Bind

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



