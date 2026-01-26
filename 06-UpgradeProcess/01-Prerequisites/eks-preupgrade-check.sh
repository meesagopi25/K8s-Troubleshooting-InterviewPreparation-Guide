
#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------
# Input parameters
# --------------------------------------------------
CLUSTER="${1:-}"
REGION="${2:-}"
TARGET_VERSION="${3:-}"

if [[ -z "$CLUSTER" || -z "$REGION" || -z "$TARGET_VERSION" ]]; then
  echo "Usage: $0 <cluster-name> <region> <target-k8s-version>"
  exit 1
fi

REPORT="eks-upgrade-go-nogo-report.txt"
STATUS_GO=true

# --------------------------------------------------
# Helper functions
# --------------------------------------------------
log() {
  echo "$1" | tee -a "$REPORT"
}

pass() {
  log "✅ PASS"
}

fail() {
  log "❌ FAIL"
  STATUS_GO=false
}

# --------------------------------------------------
# Header
# --------------------------------------------------
echo "==================================================" | tee "$REPORT"
echo "EKS PRE-UPGRADE COMPATIBILITY REPORT" | tee -a "$REPORT"
echo "Cluster        : $CLUSTER" | tee -a "$REPORT"
echo "Region         : $REGION" | tee -a "$REPORT"
echo "Target K8s     : $TARGET_VERSION" | tee -a "$REPORT"
echo "Generated On   : $(date -u)" | tee -a "$REPORT"
echo "==================================================" | tee -a "$REPORT"
echo | tee -a "$REPORT"

# --------------------------------------------------
# Kubernetes Version
# --------------------------------------------------
log "[Kubernetes]"
CURRENT_K8S=$(kubectl version -o json | jq -r '.serverVersion.gitVersion')
log "Current Version : $CURRENT_K8S"
log "Target Version  : v$TARGET_VERSION"
pass
echo | tee -a "$REPORT"

# --------------------------------------------------
# Function: Check EKS-managed addon compatibility
# --------------------------------------------------
check_addon() {
  local ADDON="$1"

  log "[$ADDON]"

  INSTALLED=$(aws eks describe-addon \
    --cluster-name "$CLUSTER" \
    --addon-name "$ADDON" \
    --region "$REGION" \
    --query 'addon.addonVersion' \
    --output text 2>/dev/null || echo "NotInstalled")

  log "Installed Version : $INSTALLED"

  SUPPORTED=$(aws eks describe-addon-versions \
    --addon-name "$ADDON" \
    --kubernetes-version "$TARGET_VERSION" \
    --region "$REGION" \
    --query 'addons[].addonVersions[].addonVersion' \
    --output text)

  log "Supported Versions: ${SUPPORTED:-None}"

  if [[ "$INSTALLED" == "NotInstalled" ]]; then
    log "Addon not installed – SKIPPED"
    pass
  elif echo "$SUPPORTED" | grep -qw "$INSTALLED"; then
    pass
  else
    log "Installed version NOT supported on Kubernetes $TARGET_VERSION"
    fail
  fi

  echo | tee -a "$REPORT"
}

# --------------------------------------------------
# EKS Managed Add-ons
# --------------------------------------------------
log "[EKS Managed Add-ons Compatibility]"
check_addon "vpc-cni"
check_addon "coredns"
check_addon "kube-proxy"
check_addon "aws-ebs-csi-driver"
check_addon "aws-efs-csi-driver"

# --------------------------------------------------
# Ingress Controllers
# --------------------------------------------------
log "[Ingress Controllers]"

if kubectl -n kube-system get deployment aws-load-balancer-controller &>/dev/null; then
  VERSION=$(kubectl -n kube-system get deployment aws-load-balancer-controller \
    -o jsonpath='{.spec.template.spec.containers[0].image}')
  log "AWS Load Balancer Controller: $VERSION"
  log "Compatibility must be verified against AWS support matrix"
  pass
else
  log "AWS Load Balancer Controller: Not installed"
  pass
fi

echo | tee -a "$REPORT"

# --------------------------------------------------
# Service Mesh
# --------------------------------------------------
log "[Service Mesh]"

if kubectl get ns istio-system &>/dev/null; then
  ISTIO_VER=$(kubectl -n istio-system get deployment istiod \
    -o jsonpath='{.spec.template.spec.containers[0].image}')
  log "Istio detected: $ISTIO_VER"
  log "Manual compatibility verification REQUIRED"
  fail
elif kubectl get ns linkerd &>/dev/null; then
  LINKERD_VER=$(kubectl -n linkerd get deployment linkerd-controller \
    -o jsonpath='{.spec.template.spec.containers[0].image}')
  log "Linkerd detected: $LINKERD_VER"
  log "Manual compatibility verification REQUIRED"
  fail
else
  log "No service mesh detected"
  pass
fi

echo | tee -a "$REPORT"

# --------------------------------------------------
# Admission Controllers
# --------------------------------------------------
log "[Admission Controllers]"

if kubectl get ns gatekeeper-system &>/dev/null; then
  log "OPA Gatekeeper detected – API compatibility review REQUIRED"
  fail
elif kubectl get ns kyverno &>/dev/null; then
  log "Kyverno detected – policy compatibility review REQUIRED"
  fail
else
  log "No admission controllers blocking upgrade"
  pass
fi

echo | tee -a "$REPORT"

# --------------------------------------------------
# Final Decision
# --------------------------------------------------
log "=================================================="
if $STATUS_GO; then
  log "FINAL DECISION: ✅ GO FOR KUBERNETES UPGRADE"
else
  log "FINAL DECISION: ❌ NO-GO – REMEDIATION REQUIRED"
fi
log "=================================================="
