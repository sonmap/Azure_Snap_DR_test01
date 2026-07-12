#!/usr/bin/env bash
set -euo pipefail

PRIMARY_HEALTH_URL="${PRIMARY_HEALTH_URL:?Set PRIMARY_HEALTH_URL, for example http://<krc-lb-fqdn>:8080/health}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

curl -fsS --max-time 10 "$PRIMARY_HEALTH_URL" >/dev/null
"$ROOT_DIR/scripts/traffic-switch.sh" primary

echo "Traffic Manager switched to Korea Central."
