#!/usr/bin/env bash
# Put Azure API Management (Consumption tier) in front of PlaceFinder.
# One wildcard operation per method forwards all paths to the container app.
# Clients need a subscription key; the policy rate-limit allows each
# subscription CALLS requests per PERIOD seconds.
# Usage: ./create-api-gateway.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
CALLS=30
PERIOD=60
API_VERSION=2024-05-01   # REST API of API Management, for az rest
check_login
ensure_providers Microsoft.ApiManagement
load_state t03
[[ -n "${SERVICE_URL:-}" ]] || die "No container app from t03. Run ./update-service.sh first."
rg=$(rg_name "$LAB")
ensure_rg "$LAB"

# API Management names are global (<name>.azure-api.net)
apim=$(name "$(suffix)-apim")
if ! az apim show --resource-group "$rg" --name "$apim" --output none 2>/dev/null; then
  log "Creating API Management $apim, tier Consumption (a few minutes) ..."
  az apim create --resource-group "$rg" --name "$apim" --location "$AZURE_LOCATION" --sku-name Consumption \
    --publisher-email "$ALERT_EMAIL" --publisher-name "PlaceFinder $OWNER" \
    --tags "course=$COURSE_TAG" "lab=$LAB" --output none
fi
save_state "$LAB" APIM_NAME "$apim"
apim_id=$(az apim show --resource-group "$rg" --name "$apim" --query id --output tsv)
arm="https://management.azure.com$apim_id"

log "Creating API placefinder with path /placefinder ..."
az apim api create --resource-group "$rg" --service-name "$apim" --api-id placefinder \
  --display-name PlaceFinder --path placefinder --protocols https \
  --service-url "$SERVICE_URL" --subscription-required true --output none
for method in GET POST PUT DELETE; do
  az apim api operation create --resource-group "$rg" --service-name "$apim" --api-id placefinder \
    --operation-id "all-${method,,}" --display-name "$method all" --method "$method" \
    --url-template "/*" --output none
done

# Policies are XML documents; the az CLI has no command for them, so the
# script calls the REST API of Azure Resource Manager directly
log "Setting the policy rate-limit: $CALLS calls per $PERIOD seconds and subscription ..."
policy="<policies>
  <inbound>
    <base />
    <rate-limit calls=\"$CALLS\" renewal-period=\"$PERIOD\"
                remaining-calls-header-name=\"X-RateLimit-Remaining\"
                total-calls-header-name=\"X-RateLimit-Limit\" />
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>"
az rest --method put --url "$arm/apis/placefinder/policies/policy?api-version=$API_VERSION" \
  --body "$(python3 -c 'import json, sys; print(json.dumps({"properties": {"format": "rawxml", "value": sys.argv[1]}}))' "$policy")" \
  --output none

log "Creating a subscription for the API and reading its key ..."
az rest --method put --url "$arm/subscriptions/placefinder-test?api-version=$API_VERSION" \
  --body "{\"properties\": {\"scope\": \"$apim_id/apis/placefinder\", \"displayName\": \"PlaceFinder test\", \"state\": \"active\"}}" \
  --output none
key=$(az rest --method post --url "$arm/subscriptions/placefinder-test/listSecrets?api-version=$API_VERSION" \
  --query primaryKey --output tsv)

gateway=$(az apim show --resource-group "$rg" --name "$apim" --query gatewayUrl --output tsv)
save_state "$LAB" API_URL "$gateway/placefinder"
save_state "$LAB" API_HEADER "Ocp-Apim-Subscription-Key: $key"
cat <<INFO

API Management: $gateway/placefinder  ($CALLS calls per $PERIOD seconds and subscription)
  Test:        ./smoke-test.sh --gateway
  Rate limit:  ./rate-limit-test.sh
  Without key: curl --include $gateway/placefinder/health
  Delete:      ./destroy-api-gateway.sh
The key is stored in ../.state/$LAB.env (API_HEADER).
INFO
