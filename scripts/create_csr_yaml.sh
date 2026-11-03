#!/bin/bash
set -euo pipefail

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