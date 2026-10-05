#!/usr/bin/env bash
# Register the resource providers used in the course (once per subscription).
# Registration is free and takes a few minutes.
# Usage: ./register-providers.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
ensure_providers Microsoft.Compute Microsoft.Network Microsoft.Storage \
  Microsoft.App Microsoft.OperationalInsights Microsoft.DBforPostgreSQL \
  Microsoft.Web Microsoft.ApiManagement Microsoft.ManagedIdentity \
  Microsoft.Consumption Microsoft.CostManagement
log "All resource providers are registered."
