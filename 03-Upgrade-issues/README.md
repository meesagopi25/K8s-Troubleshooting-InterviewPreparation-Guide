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

If you want:

* A failing liveness probe example
* A canary rollout where v2 fails
* A diagram that shows the flow of a failed rolling update

Just tell me!
