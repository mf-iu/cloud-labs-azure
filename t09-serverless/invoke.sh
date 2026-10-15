#!/usr/bin/env bash
# Call the HTTP trigger of the function and show the result.
# Usage: ./invoke.sh [YYYY-MM-DD]   (default: yesterday)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
tofu_out() { "$REPO_ROOT/tools/tofu.sh" "$REPO_ROOT/t09-serverless/infra" output -raw "$1"; }
app=$(tofu_out function_app_name)
rg=$(tofu_out resource_group)
host=$(az functionapp show --resource-group "$rg" --name "$app" --query defaultHostName --output tsv)
key=$(az functionapp keys list --resource-group "$rg" --name "$app" --query functionKeys.default --output tsv)

curl --fail --silent --show-error --request POST "https://$host/api/sync?date=${1:-}&code=$key"
echo
