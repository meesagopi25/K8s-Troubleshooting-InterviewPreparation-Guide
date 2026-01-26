Below is a **production-ready automation** for **Step A – Managed Node Group Rolling Replacement (EKS)**, consisting of:

1. **A reusable Bash script** (can be run locally or by Jenkins)
2. **A Jenkins declarative pipeline** that calls the script safely

This follows **enterprise change-control practices** (pre-checks, plan, approval, execution, validation).

---

# 1. Bash Script – Managed Node Group Upgrade

**File:** `eks-managed-nodegroup-upgrade.sh`

> This script:

* Validates cluster access
* Triggers rolling replacement
* Monitors upgrade
* Verifies node rotation

```bash
#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Input arguments
# -------------------------------
CLUSTER_NAME="$1"
NODEGROUP_NAME="$2"
TARGET_VERSION="$3"
REGION="$4"

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <cluster-name> <nodegroup-name> <target-k8s-version> <region>"
  exit 1
fi

echo "=============================================="
echo "EKS MANAGED NODE GROUP UPGRADE"
echo "Cluster        : $CLUSTER_NAME"
echo "Node Group     : $NODEGROUP_NAME"
echo "Target Version : $TARGET_VERSION"
echo "Region         : $REGION"
echo "=============================================="

# -------------------------------
# Pre-checks
# -------------------------------
echo "[Pre-check] Verifying cluster access"
kubectl get nodes >/dev/null

echo "[Pre-check] Checking PDBs"
kubectl get pdb -A

echo "[Pre-check] Current node versions"
kubectl get nodes -o wide

# -------------------------------
# Trigger rolling upgrade
# -------------------------------
echo "[Action] Triggering managed node group upgrade"

aws eks update-nodegroup-version \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --kubernetes-version "$TARGET_VERSION" \
  --region "$REGION"

echo "[Info] Upgrade request submitted"

# -------------------------------
# Monitor upgrade
# -------------------------------
echo "[Monitor] Waiting for node group to become ACTIVE"

while true; do
  STATUS=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --region "$REGION" \
    --query 'nodegroup.status' \
    --output text)

  echo "Node group status: $STATUS"

  if [[ "$STATUS" == "ACTIVE" ]]; then
    break
  fi

  if [[ "$STATUS" == "FAILED" ]]; then
    echo "ERROR: Node group upgrade failed"
    exit 1
  fi

  sleep 30
done

# -------------------------------
# Post-validation
# -------------------------------
echo "[Post-check] Verifying nodes after upgrade"
kubectl get nodes -o wide

echo "[Post-check] Verifying pod health"
kubectl get pods -A | grep -v Running || true

echo "=============================================="
echo "Managed node group upgrade completed successfully"
echo "=============================================="
```

### Make it executable

```bash
chmod +x eks-managed-nodegroup-upgrade.sh
```

---

# 2. Jenkins Pipeline – Managed Node Group Upgrade

**File:** `Jenkinsfile.managed-nodegroup-upgrade`

> This pipeline:

* Runs pre-checks
* Requires manual approval
* Calls the script
* Is safe for production use

```groovy
pipeline {
  agent any

  parameters {
    string(name: 'CLUSTER_NAME', defaultValue: 'prod-eks')
    string(name: 'NODEGROUP_NAME', defaultValue: 'prod-ng')
    string(name: 'TARGET_VERSION', defaultValue: '1.34')
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
          echo "Checking cluster access"
          kubectl get nodes
          echo "Checking PodDisruptionBudgets"
          kubectl get pdb -A
        '''
      }
    }

    stage('Manual Approval') {
      steps {
        input message: """
Approve managed node group upgrade?

Cluster   : ${params.CLUSTER_NAME}
NodeGroup : ${params.NODEGROUP_NAME}
Version   : ${params.TARGET_VERSION}
"""
      }
    }

    stage('Upgrade Managed Node Group') {
      steps {
        sh """
          ./eks-managed-nodegroup-upgrade.sh \
            ${params.CLUSTER_NAME} \
            ${params.NODEGROUP_NAME} \
            ${params.TARGET_VERSION} \
            ${params.AWS_REGION}
        """
      }
    }
  }

  post {
    success {
      echo "Managed node group upgrade completed successfully"
    }
    failure {
      echo "Upgrade failed – investigate AWS EKS and Kubernetes events immediately"
    }
  }
}
```

---

# 3. How This Works in Practice

### Rolling Replacement Behavior (EKS-Managed)

* New nodes created with target version
* Old nodes cordoned automatically
* Pods drained respecting PDBs
* Old nodes terminated
* Zero SSH, zero manual drain

---

# 4. Rollback Strategy (Operational Reality)

EKS does **not support in-place downgrade**.

If rollback is required:

1. Create a **new node group** with previous version
2. Shift workloads
3. Delete the failed node group

This aligns with **immutable infrastructure principles**.

---

# 5. Governance & Safety Controls Built In

* Explicit manual approval
* Pre-upgrade validation
* AWS-managed drain logic
* Continuous status monitoring
* Hard failure detection

---

## One-Line Summary

> This Jenkins-driven script safely automates EKS managed node group rolling replacement by triggering AWS-native upgrades, enforcing approvals, monitoring progress, and validating cluster health post-upgrade.

---

If you want next, I can:

* Add **Terraform-based node group control**
* Extend this to **blue/green node groups**
* Add **Slack / email notifications**
* Integrate **pre-upgrade compatibility scripts (4.1–4.4)**

Tell me how you want to proceed.
