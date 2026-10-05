#!/usr/bin/env bash
# Delete the resource group of lab t04 with all network resources.
# Usage: ./destroy-vnet.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t04
check_login
confirm "Delete resource group $(rg_name "$LAB") with network, NAT gateway and VM?" || exit 0
delete_rg "$LAB"
clear_state "$LAB"
log "Network deleted."
