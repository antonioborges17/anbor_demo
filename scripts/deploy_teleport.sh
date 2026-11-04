#!/bin/bash
set -euo pipefail

# Run on the control-plane node, after enable_tls.sh (needs ingress-nginx and lab-ca-issuer).
# Safe to re-run. Override versions with:
#   TELEPORT_CHART_VERSION=X.Y.Z LOCAL_PATH_VERSION=vX.Y.Z ./deploy_teleport.sh
cd "$(dirname "$0")"

LOCAL_PATH_VERSION="${LOCAL_PATH_VERSION:-v0.0.37}"
TELEPORT_CHART_VERSION="${TELEPORT_CHART_VERSION:-18.*}"

# Cluster admin installs Teleport (the chart creates cluster-scoped resources);
# web-admin stays limited to its namespace. Switch back even if a step fails.
kubectl config use-context kubernetes-admin@kubernetes
trap 'kubectl config use-context web-admin-context' EXIT

# kubeadm ships no StorageClass: install local-path-provisioner for Teleport's PVC
kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml"
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=120s

# Install Teleport. The release name must stay "teleport": teleport-values.yaml
# refers to the Secret teleport-tls, which is named after the release.
helm repo add teleport https://charts.releases.teleport.dev
helm repo update

# Create the namespace up front so Pod Security Admission applies from the first pod
# (helm's --create-namespace can't set labels). Written to tolerate re-runs.
kubectl create namespace teleport --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace teleport --overwrite pod-security.kubernetes.io/enforce=baseline

helm upgrade --install teleport teleport/teleport-cluster \
  -n teleport \
  --version "$TELEPORT_CHART_VERSION" \
  -f teleport-values.yaml \
  --wait --timeout 10m

kubectl -n teleport get pods,certificate,ingress
