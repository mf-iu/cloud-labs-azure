#!/usr/bin/env bash
# Delete the resource group of lab t03 with environment and container app.
# Usage: ./destroy.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t03
check_login
confirm "Delete resource group $(rg_name "$LAB") with the container app?" || exit 0
delete_rg "$LAB"
clear_state "$LAB"
log "Done."
