#!/usr/bin/env bash
# Create a read-only SAS URL (valid for one hour) and test it: without SAS
# token, with a range request and with a CORS preflight of the map. For a
# PMTiles file, also print the address of the map with these tiles.
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
curl --silent --output /dev/null --write-out '%{http_code}\n' "https://$STORAGE_ACCOUNT.blob.core.windows.net/data/$blob" || true

log "Range request for the first 100 bytes (expect 206 Partial Content):"
curl --silent --dump-header - --output /dev/null --range 0-99 "$url" \
  | grep --ignore-case --extended-regexp '^HTTP|^content-range|^content-length' || true

log "CORS preflight of the map at http://localhost:5173 (expect Access-Control-Allow-Origin):"
curl --silent --request OPTIONS --dump-header - --output /dev/null \
  --header "Origin: http://localhost:5173" --header "Access-Control-Request-Method: GET" \
  --header "Access-Control-Request-Headers: range" "$url" \
  | grep --ignore-case --extended-regexp '^HTTP|^access-control-allow-origin' || true

if [[ "$blob" == *.pmtiles ]]; then
  # the map of PlaceFinder: python3 -m http.server 5173 --directory frontend
  printf '\nMap with these tiles (URL-encoded):\nhttp://localhost:5173/?tiles=%s\n' \
    "$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$url")"
fi
