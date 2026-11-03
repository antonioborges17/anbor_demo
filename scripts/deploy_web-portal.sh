#!/bin/bash
set -euo pipefail

# Set context to web-admin user
kubectl config use-context web-admin-context

# Load the custom web page into a ConfigMap (create or update)
kubectl create configmap web-portal-content \
  --from-file=index.html=web-portal/index.html \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy nginx (2 replicas) serving the custom page, plus its ClusterIP service
kubectl apply -f nginx-deployment.yaml
kubectl rollout status deployment/nginx --timeout=120s
