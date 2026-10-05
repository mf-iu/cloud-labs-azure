#!/usr/bin/env bash
# Delete the resource group of lab t07 with the storage account.
# Usage: ./destroy-storage.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t07
check_login
confirm "Delete resource group $(rg_name "$LAB") with the storage account and all data?" || exit 0
delete_rg "$LAB"
clear_state "$LAB"
log "Storage deleted."
