#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_USER="${SSH_USER:-azureuser}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/azure_snapshot_dr}"

PRIMARY_IP="$(terraform -chdir="$ROOT_DIR/terraform/10-primary" output -raw management_public_ip)"
PRIMARY_FQDN="$(terraform -chdir="$ROOT_DIR/terraform/00-network" output -raw primary_service_fqdn)"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: SSH private key not found: $SSH_KEY" >&2
  exit 1
fi

echo "Validating primary VM at $PRIMARY_IP"

ssh \
  -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  "$SSH_USER@$PRIMARY_IP" \
  'set -euo pipefail

   echo "===== cloud-init ====="
   sudo cloud-init status --long
   test "$(sudo cloud-init status --format json | python3 -c "import json,sys; print(json.load(sys.stdin).get(\"status\",\"\"))")" = "done"

   echo "===== disks ====="
   findmnt /data
   findmnt /var/lib/mysql
   test "$(findmnt -n -o SOURCE /var/lib/mysql)" = "/data/mysql"

   echo "===== services ====="
   sudo systemctl is-active mysql tomcat9 dr-metadata.timer dr-health.timer
   sudo systemctl is-enabled mysql tomcat9 dr-metadata.timer dr-health.timer

   echo "===== mysql ====="
   sudo mysqladmin --protocol=socket -uroot ping
   sudo mysql -e "SELECT * FROM dr_demo.instance_info\\G"

   echo "===== local health ====="
   test "$(curl -fsS http://127.0.0.1:8080/health)" = "OK"
  '

echo "===== load balancer health ====="
test "$(curl -fsS "http://${PRIMARY_FQDN}:8080/health")" = "OK"

echo "Primary VM validation completed successfully."
