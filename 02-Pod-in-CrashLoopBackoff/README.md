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


