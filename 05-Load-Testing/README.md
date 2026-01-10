
To demonstrate load testing on your **KIND (Kubernetes in Docker)** cluster, we will deploy a simple web application, set up a Horizontal Pod Autoscaler (HPA), and then use a load-generation pod to trigger a scaling event.

### Prerequisites

Ensure your KIND cluster has the **Metrics Server** installed, as HPA requires it to function:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Patch to allow insecure kubelet traffic in KIND
kubectl patch deployment metrics-server -n kube-system --type='json' -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

```

---

### Step 1: Deploy the Target Application

We will deploy a simple PHP application that performs heavy calculations to consume CPU.

```yaml
# app-setup.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  selector:
    matchLabels:
      run: php-apache
  replicas: 1
  template:
    metadata:
      labels:
        run: php-apache
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 500m
          requests:
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
spec:
  ports:
  - port: 80
  selector:
    run: php-apache

```

**Run:** `kubectl apply -f app-setup.yaml`

---

### Step 2: Create the Horizontal Pod Autoscaler (HPA)

This tells Kubernetes to scale the deployment up to 10 replicas if the CPU usage exceeds 50%.

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

```

---

### Step 3: Perform the Load Test

Following the logic in your provided image, we will run a load generator from a **separate pod**.

1. **Open a new terminal** to watch the scaling happen:
```bash
kubectl get hpa php-apache -w

```


2. **In your main terminal**, run the load generator pod:
```bash
kubectl run -it --rm loadgen --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"

```


* This generates continuous traffic to the `php-apache` service.
* `wget` hits the service in a tight loop, causing the CPU in the app pods to spike.



---

### Step 4: Monitoring Results

While the `loadgen` pod is running, observe the changes in your "watch" terminal:

* **Watch HPA:** You will see the `TARGETS` percentage rise from `0%/50%` to much higher values (e.g., `250%/50%`).
* **Watch Pods:** Open another terminal and run `kubectl get pods -w`. You will see new `php-apache` pods transitioning from `Pending` to `ContainerCreating` to `Running` as the cluster scales out.

### Step 5: Adjust and Analyze

Once you stop the `loadgen` pod (Ctrl+C), the CPU usage will drop. After a few minutes (the "cool down" period), Kubernetes will scale the replicas back down to 1. Based on these results, you can now:

* Adjust CPU **limits** if the app crashed under load.
* Modify HPA **thresholds** if it scaled too slowly.

**Would you like me to show you how to use a more advanced tool like k6 or Locust inside your KIND cluster for detailed performance metrics?**
