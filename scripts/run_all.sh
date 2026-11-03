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

  if [[ "$script" == "install_k8s_cluster.sh" ]]; then
    echo
    echo "==> ACTION REQUIRED: run join_worker.sh on every worker node now."
    while true; do
      read -r -p "Has join_worker.sh been run on all worker nodes? [y/n] " answer </dev/tty
      case "$answer" in
        [Yy]*) break ;;
        [Nn]*) echo "Run join_worker.sh on each worker node, then answer 'y' to continue." ;;
        *) echo "Please answer y or n." ;;
      esac
    done
  fi
done

echo "==> All scripts completed"
