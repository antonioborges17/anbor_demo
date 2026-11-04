#!/bin/bash
set -euo pipefail

# Generate a key and CSR
openssl genrsa -out web-admin.key 2048
openssl req -new -key web-admin.key -out web-admin.csr -subj "/CN=web-admin/O=web-team"

cat <<EOF > web-admin-csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: web-admin
spec:
  request: $(base64 -w0 < web-admin.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

# Submit the CSR to the cluster
kubectl apply -f web-admin-csr.yaml

# Approve the CSR and extract the certificate
kubectl get csr
kubectl certificate approve web-admin
kubectl get csr web-admin -o jsonpath='{.status.certificate}' | base64 -d > web-admin.crt

# Create the namespace and a least-privilege Role
kubectl create namespace web-portal

kubectl create role web-deployer -n web-portal \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=deployments.apps,replicasets.apps,pods,pods/log,services,configmaps

# Bind the Role to the user
kubectl create rolebinding web-portal-deployer -n web-portal \
  --role=web-deployer --user=web-admin

# Create a kubectl context for the user
kubectl config set-credentials web-admin \
  --client-key=web-admin.key \
  --client-certificate=web-admin.crt \
  --embed-certs=true

kubectl config set-context web-admin-context \
  --cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') \
  --user=web-admin \
  --namespace=web-portal

# Verify permissions (still as cluster admin, since --as requires impersonation rights)
kubectl auth can-i create deployments -n web-portal --as web-admin   # expected: yes
if kubectl auth can-i get nodes --as web-admin; then                 # expected: no
  echo "ERROR: web-admin should not be able to get nodes" >&2
  exit 1
fi