#!/usr/bin/env bash
# Delete API Management (resource group of lab t05).
# Usage: ./destroy-api-gateway.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t05
check_login
confirm "Delete resource group $(rg_name "$LAB") with API Management?" || exit 0
delete_rg "$LAB"
clear_state "$LAB"
log "API Management deleted. Deleted instances stay reserved (soft delete);"
log "to reuse the name: az apim deletedservice purge --service-name <name> --location $AZURE_LOCATION"
