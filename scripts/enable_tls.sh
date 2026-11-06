#!/bin/bash
set -euo pipefail

# Switch context to default kubernetes admin to install cert-manager
kubectl config use-context kubernetes-admin@kubernetes

# Install cert-manager to manage TLS certificates
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true

kubectl get pods -n cert-manager      # wait until all pods are Running

# Install Ingress Controller (nginx) to handle TLS termination
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

kubectl get pods,svc -n ingress-nginx

# Create a self-signed CA (demo use only)
kubectl apply -f self-signed-ca.yaml
kubectl get clusterissuer      # both should show READY True

# Wait for the cluster issuers to become ready
kubectl wait --for=condition=Ready clusterissuer --all --timeout=180s

# Grant web-admin the right to manage Ingresses in its own namespace (admin)
kubectl create role ingress-manager -n web-portal \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=ingresses.networking.k8s.io

kubectl create rolebinding web-portal-ingress -n web-portal \
  --role=ingress-manager --user=web-admin --group=web-team

# Generate Ingress with a TLS certificate (as web-admin)
kubectl config use-context web-admin-context
sleep 60
kubectl apply -n web-portal -f ingress-tls-cert.yaml

# Verify the certificate (as cluster admin)
kubectl config use-context kubernetes-admin@kubernetes
# cert-manager creates the Certificate shortly after the Ingress, so wait for it to exist first
kubectl wait --for=create certificate/nginx-tls -n web-portal --timeout=120s
kubectl wait --for=condition=Ready certificate/nginx-tls -n web-portal --timeout=180s || {
  kubectl describe certificate nginx-tls -n web-portal
  exit 1
}
kubectl get certificate -n web-portal
kubectl get ingress -n web-portal

# Switch back to web-admin context
kubectl config use-context web-admin-context