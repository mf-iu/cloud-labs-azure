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
[[ "$(az group exists -n "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-storage.sh first."
ensure_rg "$LAB"
cd "$(dirname "$0")"

account=$(storage_name "$LAB")
log "Creating storage account $account (Standard_LRS, no public blobs, TLS 1.2) ..."
az storage account create -g "$rg" -n "$account" -l "$AZURE_LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags "course=$COURSE_TAG" "lab=$LAB" -o none
save_state "$LAB" STORAGE_ACCOUNT "$account"

# The data commands below authenticate with the account key
export AZURE_STORAGE_ACCOUNT="$account"
AZURE_STORAGE_KEY=$(az storage account keys list -g "$rg" -n "$account" --query '[0].value' -o tsv)
export AZURE_STORAGE_KEY

az storage container create -n data -o none
az storage cors add --services b --methods GET HEAD --origins '*' \
  --allowed-headers range if-none-match --exposed-headers etag content-length content-range \
  --max-age 3600
az storage account management-policy create -g "$rg" --account-name "$account" \
  --policy @lifecycle.json -o none

log "Uploading GeoNames cities15000 as raw data ..."
az storage blob upload -c data -n raw/geonames/cities15000.txt -f "$(download_cities)" --overwrite -o none
az storage blob list -c data --query '[].{name:name, size:properties.contentLength}' -o table
log "Next: ./upload.sh <file> [name] and ./sas.sh <name>"
