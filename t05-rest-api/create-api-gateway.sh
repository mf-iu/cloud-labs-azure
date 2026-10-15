#!/usr/bin/env bash
# Put Azure API Management (Consumption tier) in front of PlaceFinder.
# One wildcard operation per method forwards all paths to the container app.
# Usage: ./create-api-gateway.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
check_login
ensure_providers Microsoft.ApiManagement
load_state t03
[[ -n "${SERVICE_URL:-}" ]] || die "No container app from t03. Run ../t03-container/deploy.sh first."
rg=$(rg_name "$LAB")
ensure_rg "$LAB"

# API Management names are global (<name>.azure-api.net)
apim=$(name "$(suffix)-apim")
log "Creating API Management $apim, tier Consumption (a few minutes) ..."
az apim create --resource-group "$rg" --name "$apim" --location "$AZURE_LOCATION" --sku-name Consumption \
  --publisher-email "$ALERT_EMAIL" --publisher-name "PlaceFinder $OWNER" \
  --tags "course=$COURSE_TAG" "lab=$LAB" --output none
save_state "$LAB" APIM_NAME "$apim"

az apim api create --resource-group "$rg" --service-name "$apim" --api-id placefinder \
  --display-name PlaceFinder --path placefinder --protocols https \
  --service-url "$SERVICE_URL" --subscription-required false --output none
for method in GET POST PUT DELETE; do
  az apim api operation create --resource-group "$rg" --service-name "$apim" --api-id placefinder \
    --operation-id "all-$(tr '[:upper:]' '[:lower:]' <<<"$method")" \
    --display-name "$method all" --method "$method" --url-template "/*" --output none
done

gateway=$(az apim show --resource-group "$rg" --name "$apim" --query gatewayUrl --output tsv)
save_state "$LAB" API_URL "$gateway/placefinder"
cat <<INFO

API Management: $gateway/placefinder
  Test:    ./smoke-test.sh $gateway/placefinder
  Delete:  ./destroy-api-gateway.sh
Rate limits are XML policies in API Management (APIs > PlaceFinder >
All operations > Inbound processing). Check in the policy reference which
policies the Consumption tier supports.
INFO
