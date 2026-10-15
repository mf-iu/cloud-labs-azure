#!/usr/bin/env bash
# Delete the budget created by create-budget.sh.
# Usage: ./delete-budget.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
budget_name=$(name monthly-budget)
url="/subscriptions/$(subscription_id)/providers/Microsoft.Consumption/budgets/$budget_name?api-version=2023-05-01"
if ! az rest --method get --url "$url" --output none 2>/dev/null; then
  log "No budget $budget_name."
  exit 0
fi
confirm "Delete budget $budget_name?" || exit 0
az rest --method delete --url "$url"
log "Budget $budget_name deleted."
