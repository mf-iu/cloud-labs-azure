#!/usr/bin/env bash
# Azure specific helpers. Source after lib/common.sh.

require az
export AZURE_CORE_ONLY_SHOW_ERRORS=true   # no preview warnings in the output

check_login() {
  az account show -o none 2>/dev/null \
    || die "Not logged in to Azure. Run: az login --use-device-code"
  if [[ -n "${AZURE_SUBSCRIPTION:-}" ]]; then
    az account set --subscription "$AZURE_SUBSCRIPTION"
  fi
}

subscription_id() { az account show --query id -o tsv; }

# One resource group per lab: deleting the group deletes everything in it
rg_name() { echo "rg-$(name "$1")"; }
ensure_rg() {   # ensure_rg <lab>
  az group create -n "$(rg_name "$1")" -l "$AZURE_LOCATION" \
    --tags "course=$COURSE_TAG" "lab=$1" -o none
}
delete_rg() {   # delete_rg <lab>
  local rg
  rg=$(rg_name "$1")
  if [[ "$(az group exists -n "$rg")" == "true" ]]; then
    log "Deleting resource group $rg with all resources (takes a few minutes) ..."
    az group delete -n "$rg" --yes
  else
    log "Resource group $rg does not exist."
  fi
}

# Storage account names: 3-24 lowercase letters and digits, globally unique
storage_name() { echo "${PREFIX}${OWNER}$(suffix)$1" | tr -cd 'a-z0-9' | cut -c1-24; }

# Resource providers must be registered once per subscription
ensure_providers() {
  local ns state
  for ns in "$@"; do
    state=$(az provider show -n "$ns" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)
    if [[ "$state" != "Registered" ]]; then
      log "Registering resource provider $ns ..."
      az provider register -n "$ns" --wait
    fi
  done
}

# Settings for tools/tofu.sh (the azurerm provider needs the subscription)
tofu_provider_vars() {
  export TF_VAR_location="$AZURE_LOCATION" ARM_SUBSCRIPTION_ID
  ARM_SUBSCRIPTION_ID="$(subscription_id)"
}
backend_key_arg() { echo "key=$1/terraform.tfstate"; }
