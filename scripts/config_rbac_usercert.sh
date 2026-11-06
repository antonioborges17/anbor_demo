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

# The signer issues the certificate asynchronously, so wait for it to appear
cert=""
for _ in {1..30}; do
  cert=$(kubectl get csr web-admin -o jsonpath='{.status.certificate}')
  [[ -n "$cert" ]] && break
  sleep 2
done
if [[ -z "$cert" ]]; then
  echo "ERROR: CSR web-admin was approved but no certificate was issued within 60s" >&2
  kubectl describe csr web-admin >&2
  exit 1
fi
base64 -d <<< "$cert" > web-admin.crt

# Create the namespace (enforcing the Pod Security baseline), piped through apply to tolerate re-runs
kubectl create namespace web-portal --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace web-portal --overwrite pod-security.kubernetes.io/enforce=baseline

# Create the least-privilege Roles and bind them to the user and its group
kubectl apply -f web-admin-rbac.yaml

# Create a kubectl context for the user
kubectl config set-credentials web-admin \
  --client-key=web-admin.key \
  --client-certificate=web-admin.crt \
  --embed-certs=true

kubectl config set-context web-admin-context \
  --cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') \
  --user=web-admin \
  --namespace=web-portal

# Give the web-admin Linux user (created by cloud-init on the control plane) its own
# kubeconfig holding only the web-admin context, never the cluster-admin credentials
if id web-admin &>/dev/null; then
  tmp_kubeconfig=$(mktemp)
  kubectl config view --minify --flatten --context=web-admin-context > "$tmp_kubeconfig"
  sudo install -d -m 700 -o web-admin -g web-admin /home/web-admin/.kube
  sudo install -m 600 -o web-admin -g web-admin "$tmp_kubeconfig" /home/web-admin/.kube/config
  rm -f "$tmp_kubeconfig"
else
  echo "WARNING: Linux user web-admin not found; skipping its kubeconfig" >&2
fi

# Verify permissions (still as cluster admin, since --as requires impersonation rights)
kubectl auth can-i create deployments -n web-portal --as web-admin   # expected: yes
kubectl auth can-i list events -n web-portal --as web-admin          # expected: yes
if kubectl auth can-i get nodes --as web-admin; then                 # expected: no
  echo "ERROR: web-admin should not be able to get nodes" >&2
  exit 1
fi
if kubectl auth can-i create pods -n web-portal --as web-admin; then # expected: no
  echo "ERROR: web-admin should not be able to create Pods directly" >&2
  exit 1
fi