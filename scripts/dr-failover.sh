#!/usr/bin/env bash
set -euo pipefail

KEY_PATH="${1:-$HOME/.ssh/azure_snapshot_dr}"
ADMIN_USER="${2:-azureuser}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform/30-dr"

command -v terraform >/dev/null 2>&1 || {
  echo "terraform is required." >&2
  exit 1
}

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required." >&2
  exit 1
}

terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" apply -auto-approve

DR_IP="$(terraform -chdir="$TF_DIR" output -raw management_public_ip)"
DR_HEALTH_URL="$(terraform -chdir="$TF_DIR" output -raw dr_health_url)"

echo "DR management IP: $DR_IP"
echo "DR health URL: $DR_HEALTH_URL"

if command -v ansible-playbook >/dev/null 2>&1; then
  echo "Waiting for SSH..."
  for _ in $(seq 1 60); do
    if ssh \
      -i "$KEY_PATH" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=5 \
      "$ADMIN_USER@$DR_IP" true 2>/dev/null; then
      break
    fi
    sleep 10
  done

  ansible-playbook \
    -i "$DR_IP," \
    -u "$ADMIN_USER" \
    --private-key "$KEY_PATH" \
    "$ROOT_DIR/ansible/start-and-validate.yml"
else
  echo "Ansible is not installed. Terraform VM Extension requested service startup."
fi

echo "Waiting for DR Load Balancer health endpoint..."
for _ in $(seq 1 60); do
  if curl -fsS --max-time 5 "$DR_HEALTH_URL" >/dev/null; then
    echo "DR endpoint is healthy."
    "$ROOT_DIR/scripts/traffic-switch.sh" dr
    echo "Traffic Manager switched to Japan East."
    exit 0
  fi
  sleep 10
done

echo "DR health verification failed. Traffic Manager was not switched." >&2
exit 1
