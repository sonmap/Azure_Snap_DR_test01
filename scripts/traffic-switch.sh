#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
RESOURCE_GROUP="${TRAFFIC_MANAGER_RESOURCE_GROUP:-rg-snapdr-global}"
PROFILE_NAME="${TRAFFIC_MANAGER_PROFILE_NAME:-tm-snapdr-prod}"
PRIMARY_ENDPOINT="${PRIMARY_ENDPOINT_NAME:-endpoint-krc}"
DR_ENDPOINT="${DR_ENDPOINT_NAME:-endpoint-jpe}"
WAIT_SECONDS="${TRAFFIC_MANAGER_WAIT_SECONDS:-300}"

usage() {
  echo "Usage: $0 primary|dr|status" >&2
  exit 2
}

update_endpoint() {
  local endpoint="$1"
  local status="$2"

  az network traffic-manager endpoint update \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$PROFILE_NAME" \
    --name "$endpoint" \
    --type azureEndpoints \
    --endpoint-status "$status" \
    --only-show-errors \
    --output none
}

wait_online() {
  local endpoint="$1"
  local deadline=$((SECONDS + WAIT_SECONDS))

  while (( SECONDS < deadline )); do
    local monitor_status
    monitor_status=$(az network traffic-manager endpoint show \
      --resource-group "$RESOURCE_GROUP" \
      --profile-name "$PROFILE_NAME" \
      --name "$endpoint" \
      --type azureEndpoints \
      --query endpointMonitorStatus \
      --output tsv \
      --only-show-errors)

    echo "$endpoint monitor status: $monitor_status"

    if [[ "$monitor_status" == "Online" ]]; then
      return 0
    fi

    sleep 10
  done

  echo "$endpoint did not become Online within ${WAIT_SECONDS}s." >&2
  return 1
}

show_status() {
  az network traffic-manager endpoint list \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$PROFILE_NAME" \
    --type azureEndpoints \
    --query "[].{name:name,status:endpointStatus,monitor:endpointMonitorStatus,priority:priority,target:target}" \
    --output table
}

case "$MODE" in
  primary)
    # Enable and confirm primary first. Disable DR only after primary is online.
    update_endpoint "$PRIMARY_ENDPOINT" Enabled
    wait_online "$PRIMARY_ENDPOINT"
    update_endpoint "$DR_ENDPOINT" Disabled
    show_status
    ;;
  dr)
    # Enable and confirm DR first. Disable primary only after DR is online.
    update_endpoint "$DR_ENDPOINT" Enabled
    wait_online "$DR_ENDPOINT"
    update_endpoint "$PRIMARY_ENDPOINT" Disabled
    show_status
    ;;
  status)
    show_status
    ;;
  *)
    usage
    ;;
esac
