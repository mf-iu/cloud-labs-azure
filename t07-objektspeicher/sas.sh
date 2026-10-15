#!/usr/bin/env bash
# Create a read-only SAS URL (valid for one hour) and test a range request.
# Usage: ./sas.sh [name]   (default: raw/geonames/cities15000.txt)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
load_state t07
[[ -n "${STORAGE_ACCOUNT:-}" ]] || die "No storage account. Run ./create-storage.sh first."
blob="${1:-raw/geonames/cities15000.txt}"
export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
AZURE_STORAGE_KEY=$(az storage account keys list --name "$STORAGE_ACCOUNT" --query '[0].value' --output tsv)
export AZURE_STORAGE_KEY

expiry=$(date --utc --date '+1 hour' +%Y-%m-%dT%H:%MZ)
url=$(az storage blob generate-sas --container-name data --name "$blob" --permissions r \
  --expiry "$expiry" --https-only --full-uri --output tsv)
printf '\nSAS URL (read only, until %s):\n%s\n\n' "$expiry" "$url"

log "Without SAS token the blob is private (expect 404 or 409):"
curl --silent --output /dev/null --write-out '%{http_code}\n' "https://$STORAGE_ACCOUNT.blob.core.windows.net/data/$blob"

log "Range request for the first 100 bytes (expect 206 Partial Content):"
curl --silent --dump-header - --output /dev/null --range 0-99 "$url" | grep --ignore-case --extended-regexp '^HTTP|^content-range|^content-length'
