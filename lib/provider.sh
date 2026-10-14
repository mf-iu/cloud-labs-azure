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
# Regions this subscription may deploy to. Azure for Students and some new
# subscriptions get a policy such as "Allowed resource deployment regions"
# from Microsoft; prints nothing if there is no such restriction.
allowed_locations() {
  az policy assignment list -o json 2>/dev/null | python3 -c '
import json, sys
found = set()
for a in json.load(sys.stdin):
    title = (a.get("displayName") or a.get("name") or "").lower()
    if "region" in title or "location" in title:
        for p in (a.get("parameters") or {}).values():
            if isinstance(p, dict) and isinstance(p.get("value"), list):
                found.update(str(v).lower() for v in p["value"])
print(" ".join(sorted(found)))' || true
}

# Stop early with a clear message if AZURE_LOCATION is not allowed
check_location() {
  local allowed
  allowed=$(allowed_locations)
  if [[ -n "$allowed" && " $allowed " != *" ${AZURE_LOCATION,,} "* ]]; then
    die "AZURE_LOCATION=$AZURE_LOCATION is not allowed for this subscription. Allowed regions: $allowed. Set one of them in config.env."
  fi
}

# Fail early if the VM size cannot be used in AZURE_LOCATION. Short-term
# capacity limits only show up when the VM is created.
check_vm_size() {   # check_vm_size <size>
  local size=$1 status
  log "Checking VM size $size in $AZURE_LOCATION ..."
  status=$(az vm list-skus -l "$AZURE_LOCATION" --size "$size" \
      --resource-type virtualMachines -o json |
    python3 -c '
import json, sys
size = sys.argv[1].lower()
skus = [s for s in json.load(sys.stdin) if s["name"].lower() == size]
if not skus:
    print("not offered")
else:
    print(", ".join(r.get("reasonCode", "restricted")
                    for r in skus[0].get("restrictions") or []
                    if r.get("type") == "Location"))
' "$size")
  [[ -z "$status" ]] || die "VM size $size cannot be used in $AZURE_LOCATION ($status). Set another VM_SIZE in config.env (e.g. Standard_B2ats_v2) or another AZURE_LOCATION."
}

ensure_rg() {   # ensure_rg <lab>
  check_location
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
