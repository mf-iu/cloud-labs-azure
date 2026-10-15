#!/usr/bin/env bash
# Check the Azure CLI, the login and the selected subscription.
# Usage: ./check-cli.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

log "$(az version --query '"azure-cli"' --output tsv | sed 's/^/Azure CLI /')"
check_login
az account show --query '{subscription:name, id:id, user:user.name, tenant:tenantId, state:state}' --output table
log "Default location for the labs: $AZURE_LOCATION"
allowed=$(allowed_locations)
if [[ -z "$allowed" ]]; then
  log "No region restriction for this subscription."
elif [[ " $allowed " == *" ${AZURE_LOCATION,,} "* ]]; then
  log "Allowed regions: $allowed"
else
  warn "AZURE_LOCATION=$AZURE_LOCATION is not allowed. Allowed regions: $allowed. Set one of them in config.env."
fi

log "Budgets of this subscription:"
az rest --method get \
  --url "/subscriptions/$(subscription_id)/providers/Microsoft.Consumption/budgets?api-version=2023-05-01" \
  --query 'value[].{name:name, amount:properties.amount, spent:properties.currentSpend.amount}' --output table \
  || true
