#!/bin/bash
set -euo pipefail

# Run on the control-plane node. Executes the setup scripts in order and
# stops at the first failure.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The scripts reference files (e.g. self-signed-ca.yaml) by relative path
cd "$SCRIPT_DIR"

SCRIPTS=(
  install_k8s_cluster.sh
  config_rbac_usercert.sh
  deploy_web-portal.sh
  enable_tls.sh
)

for script in "${SCRIPTS[@]}"; do
  echo "==> Running $script"
  bash "$SCRIPT_DIR/$script"
done

echo "==> All scripts completed"
