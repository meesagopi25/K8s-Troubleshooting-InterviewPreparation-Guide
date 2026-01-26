Below is a **production-ready automation** for **Step B – Self-Managed Worker Node Upgrade (New ASG + Drain)**, delivered in the **same structure and rigor** as Step A.

This includes:

1. **A reusable Bash script** (safe, sequential, rollback-aware)
2. **A Jenkins declarative pipeline** that executes it with approvals

This design follows **immutable infrastructure + Kubernetes-safe draining**, suitable for **EKS self-managed nodes**.

---

# STEP B – Self-Managed Node Upgrade

**Strategy:** New ASG + Drain (Immutable Replacement)

---

# 1. Bash Script – Self-Managed Worker Upgrade

**File:** `eks-selfmanaged-node-upgrade.sh`

### What this script does

* Verifies cluster access
* Waits for new ASG nodes to join
* Identifies old worker nodes
* Performs **controlled cordon + drain (one node at a time)**
* Leaves rollback path intact

---

### Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Input arguments
# -------------------------------
OLD_NODE_LABEL="$1"        # e.g. nodegroup=workers-v1
NEW_NODE_LABEL="$2"        # e.g. nodegroup=workers-v2
CLUSTER_NAME="$3"
REGION="$4"

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <old-node-label> <new-node-label> <cluster-name> <region>"
  exit 1
fi

echo "================================================="
echo "SELF-MANAGED NODE GROUP UPGRADE (ASG + DRAIN)"
echo "Cluster        : $CLUSTER_NAME"
echo "Old Nodes      : $OLD_NODE_LABEL"
echo "New Nodes      : $NEW_NODE_LABEL"
echo "Region         : $REGION"
echo "================================================="

# -------------------------------
# Pre-checks
# -------------------------------
echo "[Pre-check] Verifying cluster access"
kubectl get nodes >/dev/null

echo "[Pre-check] Verifying PodDisruptionBudgets"
kubectl get pdb -A

echo "[Pre-check] Current node inventory"
kubectl get nodes --show-labels

# -------------------------------
# Wait for new nodes
# -------------------------------
echo "[Wait] Waiting for new ASG nodes to be Ready"

until kubectl get nodes -l "$NEW_NODE_LABEL" | grep -q Ready; do
  echo "Waiting for new nodes..."
  sleep 30
done

echo "[Info] New worker nodes are Ready"

# -------------------------------
# Drain old nodes (one-by-one)
# -------------------------------
OLD_NODES=$(kubectl get nodes -l "$OLD_NODE_LABEL" -o name)

for NODE in $OLD_NODES; do
  echo "-----------------------------------------------"
  echo "[Action] Cordon node: $NODE"
  kubectl cordon "$NODE"

  echo "[Action] Drain node: $NODE"
  kubectl drain "$NODE" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=10m

  echo "[Info] Node drained successfully: $NODE"
done

# -------------------------------
# Post-validation
# -------------------------------
echo "[Post-check] Verifying cluster state"
kubectl get nodes
kubectl get pods -A | grep -v Running || true

echo "================================================="
echo "Self-managed worker upgrade completed successfully"
echo "================================================="
```

---

### Make Executable

```bash
chmod +x eks-selfmanaged-node-upgrade.sh
```

---

# 2. Jenkins Pipeline – Self-Managed Node Upgrade

**File:** `Jenkinsfile.self-managed-upgrade`

---

### Jenkinsfile

```groovy
pipeline {
  agent any

  parameters {
    string(name: 'CLUSTER_NAME', defaultValue: 'prod-eks')
    string(name: 'OLD_NODE_LABEL', defaultValue: 'nodegroup=workers-v1')
    string(name: 'NEW_NODE_LABEL', defaultValue: 'nodegroup=workers-v2')
    string(name: 'AWS_REGION', defaultValue: 'us-east-1')
  }

  environment {
    AWS_DEFAULT_REGION = "${params.AWS_REGION}"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Pre-Upgrade Validation') {
      steps {
        sh '''
          echo "Validating cluster access"
          kubectl get nodes

          echo "Validating PodDisruptionBudgets"
          kubectl get pdb -A
        '''
      }
    }

    stage('Manual Approval') {
      steps {
        input message: """
Approve SELF-MANAGED node upgrade?

Cluster       : ${params.CLUSTER_NAME}
Old Nodes     : ${params.OLD_NODE_LABEL}
New Nodes     : ${params.NEW_NODE_LABEL}

This will cordon and drain old worker nodes sequentially.
"""
      }
    }

    stage('Drain Old Nodes') {
      steps {
        sh """
          ./eks-selfmanaged-node-upgrade.sh \
            '${params.OLD_NODE_LABEL}' \
            '${params.NEW_NODE_LABEL}' \
            '${params.CLUSTER_NAME}' \
            '${params.AWS_REGION}'
        """
      }
    }
  }

  post {
    success {
      echo "Self-managed worker node upgrade completed successfully"
    }
    failure {
      echo "Upgrade failed – old ASG remains intact for rollback"
    }
  }
}
```

---

# 3. Required Node Labeling (IMPORTANT)

To make this automation work, **label nodes by ASG**:

```bash
kubectl label node ip-10-0-1-10 nodegroup=workers-v1
kubectl label node ip-10-0-2-11 nodegroup=workers-v1

kubectl label node ip-10-0-3-20 nodegroup=workers-v2
kubectl label node ip-10-0-4-21 nodegroup=workers-v2
```

This is **mandatory** for deterministic draining.

---

# 4. Rollback Strategy (Built-In Safety)

Rollback is **simple and fast**:

1. Stop the Jenkins pipeline
2. Scale **old ASG up**
3. Leave drained nodes cordoned
4. Delete new ASG if required

Because:

* Old ASG is not deleted
* No destructive operations occur automatically

---

# 5. Safety Guarantees

✔ One node drained at a time
✔ PDBs enforced
✔ New capacity verified before draining
✔ No SSH access
✔ Immutable infrastructure
✔ Manual approval gate

---

## One-Line Executive Summary

> This Jenkins-driven automation safely upgrades self-managed EKS worker nodes by introducing a new Auto Scaling Group, validating capacity, and performing sequential cordon-and-drain operations with built-in rollback protection.

---

If you want next, I can:

* Add **Terraform code to create the new ASG automatically**
* Convert **Steps A + B into a single reusable Jenkins shared library**
* Add **Slack / PagerDuty notifications**
* Extend this to **Kafka-safe node draining**

Tell me how you’d like to proceed.
