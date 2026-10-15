#!/usr/bin/env bash
# Delete the state storage account. Only do this after every OpenTofu
# configuration has been destroyed (tofu destroy)!
# Usage: ./destroy-state.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
confirm "Delete resource group $(rg_name tfstate) with all OpenTofu states?" || exit 0
delete_rg tfstate
rm --force "$STATE_DIR/backend.hcl"
log "State storage deleted."
