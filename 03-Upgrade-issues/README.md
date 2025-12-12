Below is a **clear, realistic explanation WITH a full working example** that shows:

* A **rolling update failing**
* The **new pods failing readiness**
* Kubernetes **pausing the rollout**
* Automatic **rollback protection**
* How to debug and fix it

Perfect to add to interviews or a README.

---

# ✅ **Why a Rolling Update Fails When New Pods Fail Readiness**

During a rolling update:

1. Kubernetes creates a **new pod (v2)**
2. It waits for the pod to become **Ready**
3. If readiness fails too many times:

   * Kubernetes **stops the rollout**
   * It keeps the old version running
   * It marks the rollout as **“progress deadline exceeded”**

This protects you from deploying a defective version.

---

# 🚨 **Example: Rolling Update Fails Due to Wrong Readiness Probe**

Below is a Deployment that works in v1 but fails in v2.

---

# 1️⃣ **Working Version (v1): readiness probe correct**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        version: v1
    spec:
      containers:
      - name: app
        image: nginx
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
```

Apply:

```bash
kubectl apply -f web-v1.yaml
```

Pods become ready.

---

# 2️⃣ **Update to v2 — readiness probe broken**

Example: the probe points to a **non-existing path**, so readiness fails.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        version: v2
    spec:
      containers:
      - name: app
        image: nginx
        readinessProbe:
          httpGet:
            path: /healthz   # ❌ Nginx does NOT serve this path → always 404 → readiness FAILS
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
```

Apply the update:

```bash
kubectl apply -f web-v2.yaml
```

---

# 3️⃣ **What Happens During the Failed Rolling Update**

Kubernetes starts upgrading:

### ✔ Step 1 — It creates 1 surge pod:

```
web-xxx-v2   Pending → Running → NOT READY
```

### ❌ Readiness probe repeatedly fails:

```
HTTP probe failed with statuscode: 404
```

### ✔ Step 2 — Kubernetes **does NOT kill old pods**

Because:

* `maxUnavailable = 0`
* A new pod is not ready yet

### ❌ Step 3 — Rollout eventually fails with timeout:

```
kubectl rollout status deploy/web
→ error: deployment "web" exceeded its progress deadline
```

This means:

> New version is bad → rollback protection activated.

---

# 4️⃣ **Verify the failing readiness probe**

Use:

```bash
kubectl describe pod <v2-pod>
```

You will see:

```
Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 404
```

---

# 5️⃣ **Rolling update is paused — old version still serving traffic**

Check replica sets:

```bash
kubectl get rs
```

You will see:

* v1 ReplicaSet: 2 pods (still running)
* v2 ReplicaSet: 1 pod (not ready)

Traffic still goes to the healthy v1 pods → **zero downtime**.

---

# 6️⃣ **Fix the readiness probe**

Correct readiness probe:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 1
  periodSeconds: 3
```

Apply and rollout resumes:

```bash
kubectl apply -f web-v2-fixed.yaml
kubectl rollout status deploy/web
```

---

# 🎯 **OTHER COMMON REAL-WORLD CAUSES OF ROLLING UPDATE FAILURE**

| Cause                                                        | Example                               |
| ------------------------------------------------------------ | ------------------------------------- |
| Wrong readiness probe path                                   | `/healthz` instead of `/`             |
| Wrong probe port                                             | App listens on 8080, probe checks 80  |
| App starts but waits for DB                                  | Readiness fails until DB accessible   |
| App has a bug in v2                                          | CrashLoopBackOff or readiness failure |
| Misconfigured configmap/secret                               | Wrong env vars cause boot failure     |
| Using `maxUnavailable: 0` with insufficient cluster capacity | New pods can’t be scheduled           |
| DB migration breaks backward compatibility                   | v2 works but v1 fails → rollback loop |

---

# 🧠 **Why Kubernetes Rolls Back?**

Because of the deployment rule:

> A rolling update cannot continue until the new pod is **Ready**.

If readiness never succeeds → rollout freezes → protects production.

---

# 🧪 READY-TO-COPY SUMMARY FOR README

> During a rolling update, Kubernetes replaces old pods with new ones gradually.
> If the new pods fail their readiness probe (bad path/port, missing dependency, config error), Kubernetes stops the rollout and keeps the old version running.
> With `maxUnavailable: 0`, Kubernetes ensures **zero downtime** but also means a bad release will **never proceed**, effectively preventing production outages.

---

Absolutely — here is a **clean, complete, practical, step-by-step guide** to perform and test a **Zero-Downtime Deployment** in Kubernetes.
This is the *exact* version you should add to your README.

Everything below *works on any Kubernetes cluster*: Minikube, KIND, OpenShift, or cloud.

---

# ✅ **Zero-Downtime Deployment – Full Practical Lab**

This lab demonstrates:

* Rolling updates with **zero downtime**
* Readiness-driven traffic switching
* How Kubernetes prevents bad deployments
* How to test service continuity during an upgrade

---

# 🧱 **1. Create Deployment v1 (initial stable version)**

Save as **web-v1.yaml**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zero-web
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0      # Ensure no downtime (at least 2 pods always running)
      maxSurge: 1            # Add 1 extra pod temporarily during rollout
  selector:
    matchLabels:
      app: zero-web
  template:
    metadata:
      labels:
        app: zero-web
        version: v1
    spec:
      containers:
      - name: app
        image: nginx
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3
```

Apply:

```bash
kubectl apply -f web-v1.yaml
kubectl rollout status deploy/zero-web
```

Service (save as svc.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zero-web-svc
spec:
  selector:
    app: zero-web
  ports:
  - port: 80
    targetPort: 80
```

Apply:

```bash
kubectl apply -f svc.yaml
```

---

# 🧪 **2. Start a continuous traffic test (to verify zero downtime)**

Run a test pod:

```bash
kubectl run tester --rm -it --image=busybox -n default -- sh
```

Inside the shell:

```sh
while true; do wget -qO- http://zero-web-svc; echo ""; sleep 1; done
```

You should see:

```
<!DOCTYPE html> <html> ... Welcome to nginx! ...
```

Every second.

Keep this **running during the rollout**.

---

# 🚀 **3. Deploy Version v2 (upgrade without downtime)**

Let's upgrade nginx → Apache httpd (or you can modify HTML).
Save as **web-v2.yaml**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zero-web
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: zero-web
  template:
    metadata:
      labels:
        app: zero-web
        version: v2
    spec:
      containers:
      - name: app
        image: httpd:2.4
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3
```

Apply:

```bash
kubectl apply -f web-v2.yaml
kubectl rollout status deploy/zero-web
```

### ✔ Expected:

* Tester loop NEVER stops printing output.
* Traffic seamlessly shifts to v2.
* No errors, no downtime.

---

# 📌 **4. Verify Pods During Rollout**

```bash
kubectl get pods -o wide -w
```

You will see:

1. New v2 pod created → becomes Ready
2. Old v1 pod terminated
3. Repeat for 2nd pod

Zero downtime is guaranteed because:

* `maxUnavailable=0` keeps old pods serving until new pods are fully ready.
* Readiness probe ensures traffic only goes to healthy pods.

---

# ❌ **5. (Optional) Test a Broken Update — Rollout Fail Example**

Use a broken readinessProbe:

```yaml
readinessProbe:
  httpGet:
    path: /healthz   # <-- WRONG PATH
    port: 80
```

Apply:

```bash
kubectl apply -f web-v3-broken.yaml
kubectl rollout status deploy/zero-web
```

### Expected:

* New pods stay `0/1 Ready`
* Existing pods continue serving
* Rollout hangs → **no downtime**
* Eventually you see:

```
deployment "zero-web" exceeded its progress deadline
```

This shows **Kubernetes protects production** with zero downtime.

---

# 🔧 **6. Fix the rollout and resume**

Fix the readinessProbe path:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
```

Apply again:

```bash
kubectl apply -f web-v3-fixed.yaml
kubectl rollout status deploy/zero-web
```

Traffic continues uninterrupted.

---

# 🎉 **Summary – What You Achieved**

You have now tested:

### ✔ Zero-downtime rolling updates

### ✔ Readiness gates

### ✔ How Kubernetes waits before switching traffic

### ✔ Surge/Unavailable strategy behavior

### ✔ Rollback protection

### ✔ Continuous traffic testing

### ✔ Handling a broken release safely

This is exactly how real production-grade deployments are validated.

---

# Want to go deeper?

I can provide:

* Blue/Green deployment example
* Canary deployment example
* Weighted traffic split example
* A rollback demo
* A full README documentation section

Just tell me!

