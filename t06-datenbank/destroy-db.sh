#!/usr/bin/env bash
# Delete the resource group of lab t06 with the PostgreSQL server.
# Usage: ./destroy-db.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
confirm "Delete resource group $(rg_name "$LAB") with the database and all data?" || exit 0
delete_rg "$LAB"
clear_state "$LAB"
log "Database deleted."
