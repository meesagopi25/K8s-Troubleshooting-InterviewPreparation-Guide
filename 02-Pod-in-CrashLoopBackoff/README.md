Below is the **Markdown-formatted README.md section** for **CrashLoopBackOff Troubleshooting**.
You can **copy/paste directly into your GitHub README** — all formatting is GitHub-ready.

---

# 🚨 Pod Keeps Restarting (CrashLoopBackOff) — Troubleshooting Guide

A Pod enters **CrashLoopBackOff** when:

* The container **starts**,
* **Crashes**,
* Kubernetes **restarts** it,
* And this cycle repeats continuously.

This is one of the most common and most important Kubernetes troubleshooting topics, frequently asked in interviews.

---

# 🧩 General Debugging Steps

## 1️⃣ Check pod status

```bash
kubectl get pods
```

## 2️⃣ Inspect pod events

```bash
kubectl describe pod <pod>
```

Look for:

* `OOMKilled`
* `Back-off restarting failed container`
* `Error`
* `Permission denied`
* `Liveness probe failed`

## 3️⃣ Check container logs

```bash
kubectl logs <pod>
```

For a specific container:

```bash
kubectl logs <pod> -c <container>
```

## 4️⃣ Exec into pod (if it stays alive)

```bash
kubectl exec -it <pod> -- sh
```

---

# 🔥 CrashLoopBackOff — Example Scenarios & Fixes

Below are **real-world examples** that you can use for interviews and practical troubleshooting.

---

# 1️⃣ Application Error (Bad Script or Exit 1)

### Problem

The entrypoint script exits immediately → container crashes.

### YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-bad-script
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Starting && exit 1"]
```

### Debug

```bash
kubectl logs crash-bad-script
```

### Fix

```yaml
command: ["sh", "-c", "echo OK && sleep 3600"]
```

---

# 2️⃣ Application Exits Immediately (Wrong Command or Config Error)

Example:

```yaml
command: ["nginx", "-g", "daemon off;"]
```

If SSL cert missing:

```
nginx: [emerg] cannot load certificate
```

### Fix

Provide correct config or fix the command.

---

Below is a **clean, professional, GitHub-ready Markdown section** showing a **side-by-side comparison** of a *failing* vs *working* Nginx Pod in Kubernetes.

Perfect for adding to your troubleshooting README.md.

---

# 🔥 Nginx Pod Failing vs Working — Side-by-Side Examples

These two examples demonstrate how a Pod can enter **CrashLoopBackOff** due to a **wrong command or missing configuration**, and how a corrected version works normally.

---

# ❌ **Failing Example — Nginx Crashes (Wrong Config / Missing SSL Certs)**

This Pod references a **nonexistent config file**, causing Nginx to fail at startup.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-failing
spec:
  containers:
  - name: nginx
    image: nginx:latest

    # Wrong command: uses a custom config file that does NOT exist
    command: ["nginx"]
    args:
      - "-g"
      - "daemon off;"
      - "-c"
      - "/etc/nginx/invalid.conf"     # ❌ file does NOT exist
```

### 🔍 Expected Error

```text
nginx: [emerg] open() "/etc/nginx/invalid.conf" failed (No such file or directory)
Back-off restarting failed container
```

Pod enters:

```
CrashLoopBackOff
```

---

# ✅ **Working Example — Nginx Starts Successfully**

Here, we simply use the **default Nginx configuration**, which always works unless overridden.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-working
spec:
  containers:
  - name: nginx
    image: nginx:latest

    # Correct command to start nginx in the foreground
    command: ["nginx", "-g", "daemon off;"]

    ports:
    - containerPort: 80
```

### ✔ Expected Behavior

* Pod enters **Running**
* No restarts
* Nginx uses default config (`/etc/nginx/nginx.conf`)

---

# 📊 **Side-by-Side Comparison Table**

| Behavior    | ❌ Failing Pod                      | ✅ Working Pod             |
| ----------- | ---------------------------------- | ------------------------- |
| Command     | `nginx -c /etc/nginx/invalid.conf` | `nginx -g 'daemon off;'`  |
| Config used | References missing file            | Uses valid default config |
| Startup     | Crashes immediately                | Starts correctly          |
| Logs        | “cannot open … invalid.conf”       | Normal Nginx startup      |
| Pod Status  | CrashLoopBackOff                   | Running                   |
| Restarts    | Keeps restarting                   | No restarts               |

---

# 🧠 Why This Matters

This pair of examples teaches key Kubernetes interview concepts:

* How a wrong command leads to CrashLoopBackOff
* How container entrypoints work
* How to debug using logs & describe
* Understanding of daemon mode (`daemon off;`)
* How to use default configs when testing

---

# 3️⃣ OOMKilled (Out of Memory)

### Problem

Container exceeds memory limit.

### Describe output:

```
Reason: OOMKilled
```

### Example Bad YAML

```yaml
resources:
  limits:
    memory: "100Mi"
```

### Fix

Increase memory:

```yaml
resources:
  limits:
    memory: "512Mi"
```

---

Below are **full, ready-to-run Kubernetes examples** for demonstrating the **OOMKilled (Out of Memory)** scenario—both the **failing Pod** and the **fixed Pod**.
These are perfect for training, demos, and interview preparation.

---

# 🔥 **Scenario 3 — Pod OOMKilled (Out of Memory)**

A pod is OOMKilled when the **container uses more memory than its limit**, so the kernel terminates it.

---

# ❌ **Failing Example — Pod Crashes With OOMKilled**

This pod requests/limits only **100Mi**, but the container allocates far more memory intentionally, causing a crash.

### `oom-fail.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-fail
spec:
  containers:
  - name: memory-hog
    image: busybox
    command: ["sh", "-c"]

    # Allocate lots of memory intentionally — simulate memory leak
    args:
      - |
        echo "Allocating large memory...";
        dd if=/dev/zero of=/dev/null bs=1M count=500;

    resources:
      limits:
        memory: "100Mi"   # ❌ Too small → OOMKilled
```

### 🧪 What Happens

Apply:

```bash
kubectl apply -f oom-fail.yaml
```

Check status:

```bash
kubectl get pod oom-fail
```

Output:

```
oom-fail   CrashLoopBackOff
```

Now describe:

```bash
kubectl describe pod oom-fail
```

You will see:

```
Last State:  Terminated
Reason:      OOMKilled
```

---

# ✔️ **Working Example — Memory Limit Increased**

Now we increase the memory **limit** so the process can run successfully.

### `oom-fix.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-fix
spec:
  containers:
  - name: memory-hog
    image: busybox
    command: ["sh", "-c"]

    # Same memory-intensive operation
    args:
      - |
        echo "Allocating large memory...";
        dd if=/dev/zero of=/dev/null bs=1M count=500;

    resources:
      limits:
        memory: "512Mi"   # ✅ Enough memory — pod RUNS successfully
```

### 🧪 Apply and test:

```bash
kubectl apply -f oom-fix.yaml
```

Check:

```bash
kubectl get pod oom-fix
```

Expected:

```
oom-fix   Running
```

---

# 📊 Side-by-Side Summary

| Behavior          | ❌ OOMKilled Pod                           | ✅ Fixed Pod                 |
| ----------------- | ----------------------------------------- | --------------------------- |
| Memory Limit      | 100Mi                                     | 512Mi                       |
| Actual Memory Use | ~500Mi                                    | ~500Mi                      |
| Outcome           | Kernel kills container → CrashLoopBackOff | Container runs successfully |
| Describe output   | Reason: OOMKilled                         | No OOMKilled                |

---

# 🧠 Why OOMKilled Happens

Kubernetes enforces **hard memory limits**:

* If app uses **more than limit memory** → container is killed
* Restart policy triggers → CrashLoopBackOff

It **does NOT** matter what the *request* is — memory **limit** is final.

---



# 4️⃣ ImagePullBackOff Misunderstood as CrashLoopBackOff

If image is wrong:

```
Failed to pull image
```

### Fix

Use valid image:

```yaml
image: nginx:latest
```

---

# 5️⃣ Permission Denied (Filesystem or OpenShift SCC)

Example:

```yaml
securityContext:
  runAsUser: 0
```

### Error

```
Permission denied
```

### Fix

```yaml
securityContext:
  runAsNonRoot: true
```

---

# 6️⃣ Missing ConfigMap / Missing Environment Variables

### Problem

App depends on env vars; ConfigMap missing.

Example:

```yaml
env:
- name: DATABASE_URL
  valueFrom:
    configMapKeyRef:
      name: db-config
      key: url
```

### Fix

```bash
kubectl create configmap db-config --from-literal=url=mysql://db
```

---

# 7️⃣ Wrong Command / Wrong Entrypoint

Example:

```yaml
command: ["wrongbinary"]
```

### Logs:

```
exec: "wrongbinary": no such file or directory
```

### Fix

```yaml
command: ["sleep", "3600"]
```

---

# 8️⃣ Init Container Failing

### YAML

```yaml
initContainers:
- name: init
  image: busybox
  command: ["sh", "-c", "exit 1"]
```

###Pod status:

```
Init:CrashLoopBackOff
```

### Fix

Correct init script.

---

# 9️⃣ Liveness Probe Killing the Pod

### Example

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
```

If `/health` isn't ready → container killed repeatedly.

### Fixes

* Increase delay
* Fix endpoint
* Use readiness probe appropriately

---

# 🔟 Volume Mount / PVC Issues

### YAML

```yaml
volumeMounts:
- name: data
  mountPath: /data
volumes:
- name: data
  persistentVolumeClaim:
    claimName: missing-pvc
```

### Error

```
MountVolume.SetUp failed: PVC not found
```

---

# 🧰 Quick Commands Cheat Sheet

### Logs

```bash
kubectl logs <pod>
kubectl logs -f <pod>
```

### Describe

```bash
kubectl describe pod <pod>
```

### Exec

```bash
kubectl exec -it <pod> -- sh
```

### Restart count

```bash
kubectl get pods -o wide
```

---

# 🎯 Final Summary: Common CrashLoopBackOff Causes & Fixes

| Cause                    | Explanation                     | Fix                         |
| ------------------------ | ------------------------------- | --------------------------- |
| Application error        | Script exits with non-zero code | Fix entrypoint / script     |
| Wrong command            | Binary not found                | Correct command             |
| OOMKilled                | Memory limit too low            | Increase limit              |
| Liveness probe fails     | Probe kills app repeatedly      | Fix probe or increase delay |
| Missing ConfigMap/Secret | App fails at startup            | Create required resources   |
| Permission issues        | SCC/FS restrictions             | Fix permissions / SCC       |
| Init container fails     | Main container won't start      | Fix init logic              |

---


