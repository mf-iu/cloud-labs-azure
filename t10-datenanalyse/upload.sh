#!/usr/bin/env bash
# Convert cities15000 into GeoParquet and upload it into the data lake.
# Usage: ./upload.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

require uv
check_login
cd "$(dirname "$0")"
account=$("$REPO_ROOT/tools/tofu.sh" infra output -raw storage_account)
parquet="$DATA_DIR/places.parquet"

uv run export_geoparquet.py "$(download_cities)" "$parquet"
# --auth-mode login: your Entra ID login with the role from infra/main.tf
az storage blob upload --auth-mode login --account-name "$account" --container-name lake \
  --name places/places.parquet --file "$parquet" --overwrite --output none
log "Uploaded. Next: ./query-duckdb.sh"
