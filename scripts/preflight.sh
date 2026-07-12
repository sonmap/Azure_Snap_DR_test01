#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES=(
  "terraform/00-network"
  "terraform/10-primary"
  "terraform/20-automation"
  "terraform/30-dr"
)

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $command_name" >&2
    exit 1
  fi
}

read_vm_size() {
  local module_path="$1"
  local tfvars="$ROOT_DIR/$module_path/terraform.tfvars"
  local variables="$ROOT_DIR/$module_path/variables.tf"
  local value=""

  if [[ -f "$tfvars" ]]; then
    value="$(awk -F'"' '/^[[:space:]]*vm_size[[:space:]]*=/{print $2; exit}' "$tfvars")"
  fi

  if [[ -z "$value" ]]; then
    value="$(awk '
      /variable "vm_size"/ { in_block=1 }
      in_block && /default[[:space:]]*=/ {
        if (match($0, /"[^"]+"/)) {
          print substr($0, RSTART + 1, RLENGTH - 2)
          exit
        }
      }
      in_block && /^}/ { in_block=0 }
    ' "$variables")"
  fi

  printf '%s' "$value"
}

check_vm_quota() {
  local location="$1"
  local size="$2"
  local family vcpus usage limit available restrictions

  if [[ -z "$size" ]]; then
    echo "ERROR: VM size could not be determined for $location" >&2
    return 1
  fi

  family="$(az vm list-skus \
    --location "$location" \
    --resource-type virtualMachines \
    --size "$size" \
    --all \
    --query "[?name=='$size'] | [0].family" \
    --output tsv)"

  vcpus="$(az vm list-skus \
    --location "$location" \
    --resource-type virtualMachines \
    --size "$size" \
    --all \
    --query "[?name=='$size'] | [0].capabilities[?name=='vCPUs'] | [0].value" \
    --output tsv)"

  restrictions="$(az vm list-skus \
    --location "$location" \
    --resource-type virtualMachines \
    --size "$size" \
    --all \
    --query "[?name=='$size'] | [0].restrictions[].reasonCode" \
    --output tsv)"

  if [[ -z "$family" || -z "$vcpus" ]]; then
    echo "ERROR: $size is not returned for $location in this subscription." >&2
    return 1
  fi

  usage="$(az vm list-usage \
    --location "$location" \
    --query "[?name.value=='$family'] | [0].currentValue" \
    --output tsv)"

  limit="$(az vm list-usage \
    --location "$location" \
    --query "[?name.value=='$family'] | [0].limit" \
    --output tsv)"

  if [[ -z "$usage" || -z "$limit" ]]; then
    echo "ERROR: quota entry not found: location=$location family=$family" >&2
    return 1
  fi

  available=$((limit - usage))

  echo "VM quota: location=$location size=$size family=$family vCPUs=$vcpus used=$usage limit=$limit available=$available"

  if [[ -n "$restrictions" ]]; then
    echo "ERROR: SKU restrictions detected for $size in $location: $restrictions" >&2
    return 1
  fi

  if (( available < vcpus )); then
    echo "ERROR: insufficient family quota for $size in $location" >&2
    return 1
  fi

  echo "NOTE: quota and SKU checks cannot guarantee real-time regional capacity. A deployment can still return SkuNotAvailable."
}

validate_cloud_init() {
  local template="$ROOT_DIR/terraform/10-primary/cloud-init.yaml.tftpl"
  local extracted
  extracted="$(mktemp)"
  trap 'rm -f "$extracted"' RETURN

  if grep -R "cloud-init-tail.yamlfrag" "$ROOT_DIR/terraform/10-primary" >/dev/null 2>&1; then
    echo "ERROR: obsolete cloud-init fragment reference remains." >&2
    return 1
  fi

  awk '
    /^runcmd:/ { found=1; next }
    found && /^  - \|/ { next }
    found {
      sub(/^      /, "")
      print
    }
  ' "$template" > "$extracted"

  if [[ ! -s "$extracted" ]]; then
    echo "ERROR: runcmd could not be extracted from cloud-init template." >&2
    return 1
  fi

  bash -n "$extracted"
  echo "cloud-init runcmd shell syntax: OK"
}

main() {
  require_command terraform
  require_command az
  require_command python3
  require_command ssh

  cd "$ROOT_DIR"

  az account show --query '{subscription:name,id:id,user:user.name}' --output table

  terraform fmt -check -recursive
  validate_cloud_init

  for module in "${MODULES[@]}"; do
    echo "===== validating $module ====="
    terraform -chdir="$ROOT_DIR/$module" init -backend=false -input=false
    terraform -chdir="$ROOT_DIR/$module" validate
  done

  local primary_size dr_size
  primary_size="$(read_vm_size terraform/10-primary)"
  dr_size="$(read_vm_size terraform/30-dr)"

  check_vm_quota koreacentral "$primary_size"
  check_vm_quota japaneast "$dr_size"

  echo "Preflight validation completed successfully."
}

main "$@"
