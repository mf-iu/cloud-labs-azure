#!/usr/bin/env bash
# Create a storage account with a private blob container, CORS for map
# tiles and a lifecycle rule.
# Usage: ./create-storage.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t07
check_login
ensure_providers Microsoft.Storage
rg=$(rg_name "$LAB")
[[ "$(az group exists --name "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-storage.sh first."
ensure_rg "$LAB"
cd "$(dirname "$0")"

account=$(storage_name "$LAB")
log "Creating storage account $account (Standard_LRS, no public blobs, TLS 1.2) ..."
az storage account create --resource-group "$rg" --name "$account" --location "$AZURE_LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags "course=$COURSE_TAG" "lab=$LAB" --output none
save_state "$LAB" STORAGE_ACCOUNT "$account"

# The data commands below authenticate with the account key
export AZURE_STORAGE_ACCOUNT="$account"
AZURE_STORAGE_KEY=$(az storage account keys list --resource-group "$rg" --name "$account" --query '[0].value' --output tsv)
export AZURE_STORAGE_KEY

az storage container create --name data --output none
az storage cors add --services b --methods GET HEAD --origins '*' \
  --allowed-headers range if-none-match --exposed-headers etag content-length content-range \
  --max-age 3600
az storage account management-policy create --resource-group "$rg" --account-name "$account" \
  --policy @lifecycle.json --output none

log "Uploading GeoNames cities15000 as raw data ..."
az storage blob upload --container-name data --name raw/geonames/cities15000.txt --file "$(download_cities)" --overwrite --output none
az storage blob list --container-name data --query '[].{name:name, size:properties.contentLength}' --output table
log "Next: ./upload.sh <file> [name] and ./sas.sh <name>"
