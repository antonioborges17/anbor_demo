#!/bin/bash
set -euo pipefail

# Run on the control-plane node only. Writes join-worker.sh next to this script;
# copy it to each worker and run it there (the join token expires after 24h).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Calico's default pod CIDR; must not overlap the VPC (default VPC is 172.31.0.0/16)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

JOIN_CMD=$(sudo kubeadm token create --print-join-command)

cat > "$SCRIPT_DIR/join-worker.sh" <<JOIN
#!/bin/bash
set -euo pipefail
sudo $JOIN_CMD
JOIN

chmod +x "$SCRIPT_DIR/join-worker.sh"

# Configure kubectl
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Install a CNI plugin (Calico) for pod networking
# Override with: CALICO_VERSION=vX.Y.Z ./install_cni.sh
CALICO_VERSION="${CALICO_VERSION:-v3.33.0}"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"