#!/usr/bin/env bash

# Upload a file, e.g. a PMTiles extract, into the container "data".
#
# Usage: ./upload.sh <file> [name]   (default name: tiles/<name> for .pmtiles, else raw/<name>)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
load_state t07
[[ -n "${STORAGE_ACCOUNT:-}" ]] || die "No storage account. Run ./create-storage.sh first."
# ${1:?text} stops the script with this text if there is no first argument
file="${1:?Usage: $0 <file> [name]}"
# basename is the file name without its folder
default="raw/$(basename "$file")"
# PMTiles files go to tiles/, everything else to raw/
[[ "$file" != *.pmtiles ]] || default="tiles/$(basename "$file")"
blob="${2:-$default}"
# The az storage commands read account name and key from these variables; export
# passes them on
export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
AZURE_STORAGE_KEY=$(az storage account keys list --name "$STORAGE_ACCOUNT" --query '[0].value' --output tsv)
export AZURE_STORAGE_KEY
az storage blob upload --container-name data --name "$blob" --file "$file" --overwrite --output none
log "Uploaded to https://$STORAGE_ACCOUNT.blob.core.windows.net/data/$blob"
