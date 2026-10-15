#!/usr/bin/env bash
# Create a monthly cost budget for the subscription with e-mail alerts:
# 50 % and 80 % of the actual costs, 100 % of the forecast.
# The Azure CLI has no complete budget command, so the script calls the
# Cost Management REST API with "az rest".
# Usage: ./create-budget.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
budget_name=$(name monthly-budget)
url="/subscriptions/$(subscription_id)/providers/Microsoft.Consumption/budgets/$budget_name?api-version=2023-05-01"
if az rest --method get --url "$url" --output none 2>/dev/null; then
  log "Budget $budget_name exists already. To change it, run ./delete-budget.sh first."
  exit 0
fi
start=$(date --utc +%Y-%m-01T00:00:00Z)
end=$(date --utc --date "$(date --utc +%Y-%m-01) +1 year" +%Y-%m-%dT00:00:00Z)
body=$(mktemp)
trap 'rm --force "$body"' EXIT

alert() {   # alert <Actual|Forecasted> <percent>
  cat <<JSON
"$1$2": {
  "enabled": true,
  "operator": "GreaterThan",
  "threshold": $2,
  "thresholdType": "$1",
  "contactEmails": ["$ALERT_EMAIL"],
  "locale": "de-de"
}
JSON
}
cat >"$body" <<JSON
{
  "properties": {
    "category": "Cost",
    "amount": $BUDGET_AMOUNT,
    "timeGrain": "Monthly",
    "timePeriod": {"startDate": "$start", "endDate": "$end"},
    "notifications": {
      $(alert Actual 50),
      $(alert Actual 80),
      $(alert Forecasted 100)
    }
  }
}
JSON

log "Creating budget $budget_name ($BUDGET_AMOUNT per month, alerts to $ALERT_EMAIL) ..."
az rest --method put --body "@$body" --url "$url" \
  --query '{name:name, amount:properties.amount, from:properties.timePeriod.startDate}' --output table
log "Done. Check it in the portal: Cost Management > Budgets."
