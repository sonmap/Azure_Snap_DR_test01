#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES=(
  "terraform/30-dr"
  "terraform/20-automation"
  "terraform/10-primary"
  "terraform/00-network"
)

if [[ "${DESTROY_APPROVED:-no}" != "yes" ]]; then
  cat >&2 <<'EOF'
ERROR: full destroy was not approved.
Run this command only when every Snapshot DR resource may be deleted:

  DESTROY_APPROVED=yes ./scripts/destroy-all.sh
EOF
  exit 1
fi

cd "$ROOT_DIR"

for module in "${MODULES[@]}"; do
  echo
  echo "===== checking $module ====="

  terraform -chdir="$module" init -input=false

  if ! resources="$(terraform -chdir="$module" state list 2>/dev/null)"; then
    echo "No readable Terraform state for $module; skipping."
    continue
  fi

  if [[ -z "$resources" ]]; then
    echo "No managed resources in $module; skipping."
    continue
  fi

  echo "$resources"
  echo "Destroying $module ..."
  terraform -chdir="$module" destroy -auto-approve

done

find "$ROOT_DIR/terraform" -type f -name '*.tfplan' -delete

echo
cat <<'EOF'
Terraform destroy sequence completed.
Verify Azure resource-group deletion separately:
  az group list --query "[?starts_with(name,'rg-snapdr')].[name,properties.provisioningState]" -o table
EOF
