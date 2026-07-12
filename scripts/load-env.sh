#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run with: source scripts/load-env.sh" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_tf_output() {
  local module="$1"
  local name="$2"
  terraform -chdir="$ROOT_DIR/$module" output -raw "$name" 2>/dev/null || true
}

export SUBSCRIPTION_ID="$(az account show --query id --output tsv 2>/dev/null || true)"
export SSH_KEY="${SSH_KEY:-$HOME/.ssh/azure_snapshot_dr}"

export PRIMARY_RG="$(_tf_output terraform/00-network primary_resource_group_name)"
export DR_RG="$(_tf_output terraform/00-network dr_resource_group_name)"
export AUTOMATION_RG="$(_tf_output terraform/00-network automation_resource_group_name)"
export GLOBAL_RG="$(_tf_output terraform/00-network global_resource_group_name)"

export PRIMARY_FQDN="$(_tf_output terraform/00-network primary_service_fqdn)"
export DR_FQDN="$(_tf_output terraform/00-network dr_service_fqdn)"
export TM_FQDN="$(_tf_output terraform/00-network traffic_manager_fqdn)"

export PRIMARY_VM="$(_tf_output terraform/10-primary vm_name)"
export PRIMARY_IP="$(_tf_output terraform/10-primary management_public_ip)"
export PRIMARY_PRIVATE_IP="$(_tf_output terraform/10-primary private_ip)"

cat <<EOF
Environment loaded from Terraform state.
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
PRIMARY_RG=$PRIMARY_RG
PRIMARY_VM=$PRIMARY_VM
PRIMARY_IP=$PRIMARY_IP
PRIMARY_FQDN=$PRIMARY_FQDN
TM_FQDN=$TM_FQDN
SSH_KEY=$SSH_KEY
EOF
