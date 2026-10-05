#!/usr/bin/env bash
# Delete the resource group of lab t02 with VM, disk, network and public IP.
# Usage: ./destroy-vm.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t02
check_login
confirm "Delete resource group $(rg_name "$LAB") with the VM?" || exit 0
delete_rg "$LAB"
clear_state "$LAB"
log "VM deleted."
