#!/usr/bin/env bash
# Roll out a new PlaceFinder version on the container app from t03.
# Container Apps creates a new revision and switches the traffic to it.
# Usage: ./update-service.sh [tag]   (default: t05)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
tag="${1:-t05}"
rg=$(rg_name t03)
app=$(name placefinder)
az containerapp show --resource-group "$rg" --name "$app" --output none 2>/dev/null \
  || die "No container app from t03. Run ../t03-container/deploy.sh first."

log "Updating $app to $PLACEFINDER_IMAGE:$tag ..."
az containerapp update --resource-group "$rg" --name "$app" --image "$PLACEFINDER_IMAGE:$tag" --output none
az containerapp revision list --resource-group "$rg" --name "$app" \
  --query '[].{revision:name, active:properties.active, traffic:properties.trafficWeight, created:properties.createdTime}' --output table
load_state t03
log "Test it with: ./smoke-test.sh $SERVICE_URL"
