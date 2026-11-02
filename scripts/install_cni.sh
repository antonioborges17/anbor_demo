#!/bin/bash
set -euo pipefail

# Override with: CALICO_VERSION=vX.Y.Z ./install_cni.sh
CALICO_VERSION="${CALICO_VERSION:-v3.33.0}"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
