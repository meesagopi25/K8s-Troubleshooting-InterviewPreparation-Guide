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

Below is a **complete, polished, OOMKilled Troubleshooting Lab** section for your README.
You can copy/paste it **exactly as-is** into your documentation.

---

# 🔥 OOMKilled Troubleshooting Lab

### **Understanding Out-of-Memory Kills in Kubernetes**

A container is marked **OOMKilled** when it tries to use more memory than its assigned **memory limit**.
This is one of the most common causes of **CrashLoopBackOff** and a frequent **interview question**.

This lab demonstrates:

* How to reproduce OOMKilled
* How to detect it
* How to fix it
* Why some pods restart without OOMKilled
* Differences between I/O spikes vs real memory allocation

---

# 📘 Table of Contents (OOMKilled Lab)

1. What is OOMKilled?
2. How Kubernetes Enforces Memory Limits
3. Failing Pod Example (OOMKilled)
4. Working Pod Example (Fixed)
5. Why some Pods “CrashLoopBackOff” **without** OOMKilled
6. Commands for Debugging OOMKilled
7. Side-by-Side Comparison Table

---

# 1️⃣ What Does OOMKilled Mean?

A pod is **OOMKilled** when:

* It exceeds its **memory limit**, and
* The Linux kernel OOM killer terminates it

This results in:

```
Last State: Terminated
Reason:     OOMKilled
Exit Code:  137
```

Kubernetes then restarts the container → **CrashLoopBackOff**.

---

# 2️⃣ How Kubernetes Enforces Memory Limits

Memory **limits** define the *maximum* RAM the container can use.

Example:

```yaml
resources:
  limits:
    memory: "100Mi"
```

If the process tries to use more than 100Mi → **OOMKilled**.

Memory **requests** do NOT affect OOMKill.
Only **limits** matter.

---

# 3️⃣ ❌ Failing Pod Example — Forced OOMKilled

This example reliably allocates **600Mi of real memory**, exceeding the limit of **512Mi**.

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
    args:
      - |
        echo "Allocating memory...";
        head -c 600M /dev/zero > /dev/null;  # allocate 600Mi in buffers
        sleep 10;
    resources:
      limits:
        memory: "512Mi"    # ❌ too small → causes OOMKilled
```

### Expected:

```bash
kubectl describe pod oom-fail
```

Output:

```
Last State: Terminated
Reason:     OOMKilled
Exit Code: 137
```

Pod goes into:

```
CrashLoopBackOff
```

---

# 4️⃣ ✔️ Working Pod Example — Fixed Memory Limit

Increase the limit so the pod can run successfully.

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
    args:
      - |
        echo "Allocating memory...";
        head -c 600M /dev/zero > /dev/null;
        sleep 10;
    resources:
      limits:
        memory: "1Gi"     # ✅ Enough memory to run safely
```

### Expected:

```
STATUS: Running
No OOMKilled events
```

---

# 5️⃣ ❗ Why Your Pod Sometimes Shows CrashLoopBackOff but NOT OOMKilled

Commands like:

```bash
dd if=/dev/zero of=/dev/null bs=1M count=500
```

**do NOT allocate memory**.
They stream data between file descriptors (I/O), not into RAM.

Result:

* Process exits **successfully** (Exit Code 0)
* Container exits immediately
* Kubernetes restarts it
* Pod enters **CrashLoopBackOff**
* But **NO OOMKilled event appears**

This confuses many beginners and is a **common interview trick question**.

---

# 6️⃣ 🧰 Commands for Debugging OOMKilled

### Check pod details

```bash
kubectl describe pod <pod>
```

Look for:

```
Reason: OOMKilled
Exit Code: 137
```

---

### Check restart count

```bash
kubectl get pods -o wide
```

---

### Stream logs

```bash
kubectl logs -f <pod>
```

---

### Check node memory pressure

```bash
kubectl describe node <node> | grep -i memory
```

---

### Check live memory usage (needs metrics-server)

```bash
kubectl top pod
kubectl top node
```

---

# 7️⃣ 📊 Side-by-Side Comparison Table

| Scenario                   | Behavior                             | Expected Result                      |
| -------------------------- | ------------------------------------ | ------------------------------------ |
| ❌ Memory limit too small   | App allocates more memory than limit | OOMKilled → CrashLoopBackOff         |
| ❌ App exits normally       | App completes instantly              | CrashLoopBackOff (without OOMKilled) |
| ✔ Correct memory limit     | App uses memory within limit         | Pod runs normally                    |
| ✔ No memory-intensive work | No memory spike                      | Pod runs normally                    |

---

# 🎉 Summary

This OOMKilled lab teaches you:

* How to **reproduce OOMKilled** reliably
* How to differentiate between I/O vs real memory allocation
* How to inspect **Last State**, **Exit Code 137**, and **Reason: OOMKilled**
* How to fix the issue by adjusting limits
* Common misconceptions about CrashLoopBackOff

This knowledge is essential for Kubernetes interviews and real-world troubleshooting.

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


