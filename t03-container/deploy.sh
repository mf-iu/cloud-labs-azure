#!/usr/bin/env bash
# Run PlaceFinder on Azure Container Apps (serverless containers).
# The image is pulled from ghcr.io; an Azure Container Registry is not
# needed for public images and would cost money every day.
# Usage: ./deploy.sh [image]   (default: $PLACEFINDER_IMAGE:t03)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t03
image="${1:-$PLACEFINDER_IMAGE:t03}"
check_login
ensure_providers Microsoft.App Microsoft.OperationalInsights
rg=$(rg_name "$LAB")
ensure_rg "$LAB"

env_name=$(name env)
app_name=$(name placefinder)
if ! az containerapp env show -g "$rg" -n "$env_name" -o none 2>/dev/null; then
  log "Creating Container Apps environment $env_name (without Log Analytics) ..."
  az containerapp env create -g "$rg" -n "$env_name" -l "$AZURE_LOCATION" \
    --logs-destination none --tags "course=$COURSE_TAG" "lab=$LAB" -o none
fi

log "Creating container app $app_name with $image ..."
fqdn=$(az containerapp create -g "$rg" -n "$app_name" --environment "$env_name" \
  --image "$image" --target-port 8000 --ingress external \
  --cpu 0.25 --memory 0.5Gi --min-replicas 0 --max-replicas 2 \
  --tags "course=$COURSE_TAG" "lab=$LAB" \
  --query properties.configuration.ingress.fqdn -o tsv)
save_state "$LAB" SERVICE_URL "https://$fqdn"

cat <<INFO

URL:     https://$fqdn
The app scales to zero when idle; the first request then takes a few seconds.
Logs:    az containerapp logs show -g $rg -n $app_name --follow
INFO
wait_for_http "https://$fqdn/health" 300
