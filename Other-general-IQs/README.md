

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
2️⃣ Pod stuck waiting for PVC to bind. Why?
Answer:
	• kubectl describe pvc <pvc>:
		○ Check events, status.
	• Common causes:
		○ No matching PV and no dynamic provisioning.
		○ Wrong storageClassName.
		○ PV has different accessModes or insufficient size.
		○ PV has nodeAffinity that doesn’t match the node.
	• Fix:
		○ Create proper PV or correct StorageClass.
Adjust PVC size/access mode / storageClassName.




