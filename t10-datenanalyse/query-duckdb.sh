#!/usr/bin/env bash
# Run query_duckdb.py; DuckDB authenticates with your Azure CLI login.
# Usage: ./query-duckdb.sh [overture release]
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

require uv
check_login
cd "$(dirname "$0")"
account=$("$REPO_ROOT/tools/tofu.sh" infra output -raw storage_account)
uv run query_duckdb.py "$account" "${1:-${OVERTURE_RELEASE:-}}"
