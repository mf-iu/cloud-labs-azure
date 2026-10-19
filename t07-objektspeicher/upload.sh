#!/usr/bin/env bash
# Upload a file, e.g. a PMTiles extract, into the container "data".
# Usage: ./upload.sh <file> [name]   (default name: tiles/<name> for .pmtiles, else raw/<name>)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
load_state t07
[[ -n "${STORAGE_ACCOUNT:-}" ]] || die "No storage account. Run ./create-storage.sh first."
file="${1:?Usage: $0 <file> [name]}"
default="raw/$(basename "$file")"
[[ "$file" != *.pmtiles ]] || default="tiles/$(basename "$file")"
blob="${2:-$default}"
export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
AZURE_STORAGE_KEY=$(az storage account keys list --name "$STORAGE_ACCOUNT" --query '[0].value' --output tsv)
export AZURE_STORAGE_KEY
az storage blob upload --container-name data --name "$blob" --file "$file" --overwrite --output none
log "Uploaded to https://$STORAGE_ACCOUNT.blob.core.windows.net/data/$blob"
