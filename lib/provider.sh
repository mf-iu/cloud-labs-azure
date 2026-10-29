#!/usr/bin/env bash
# Helpers for the lab scripts of this repository: first the shared helpers
# of cloud-labs-local next to this repository, then the settings in
# config.env, the helpers for all cloud labs and those for Azure.
# Source this file from a script; do not execute it directly.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_LABS="${LOCAL_LABS:-$REPO_ROOT/../cloud-labs-local}"
if [[ ! -f "$LOCAL_LABS/lib/common.sh" ]]; then
  printf 'ERROR: cloud-labs-local not found next to this repository (%s).\n' "$LOCAL_LABS" >&2
  printf 'Clone it in the WSL shell: cd ~/kurs && git clone https://github.com/mf-iu/cloud-labs-local.git\n' >&2
  exit 1
fi
# shellcheck source=../../cloud-labs-local/lib/common.sh
source "$LOCAL_LABS/lib/common.sh"

# Settings for the cloud labs (copied from config.example.env, never
# committed). GITHUB_USER and PLACEFINDER_IMAGE come from config.env of
# cloud-labs-local.
[[ -f "$REPO_ROOT/config.env" ]] \
  || die "config.env not found: copy config.example.env to config.env in $REPO_ROOT and fill it in."
# shellcheck source=/dev/null
source "$REPO_ROOT/config.env"
# shellcheck disable=SC2034  # used by 02-vm/create-vm.sh
PLACEFINDER_REPO="https://github.com/$GITHUB_USER/placefinder.git"

# Tag or label value that marks every resource of the course
# shellcheck disable=SC2034  # used by the lab scripts
COURSE_TAG="cloud-computing"

# Random lowercase suffix, created once per clone, for globally unique names
suffix() {
  local file="$STATE_DIR/suffix"
  if [[ ! -s "$file" ]]; then
    python3 -c 'import secrets; print(secrets.token_hex(3))' >"$file"
  fi
  cat "$file"
}

# Resource name: name t02-vm -> pf-mf-t02-vm
name() { echo "${PREFIX}-${OWNER}-$1"; }

# Public IPv4 address of this computer, used for firewall rules
my_ip() { curl --fail --silent --show-error --max-time 10 https://checkip.amazonaws.com | tr --delete '[:space:]'; }

# Password with upper and lower case letters, digits and a symbol
random_password() {
  python3 -c 'import secrets, string
chars = string.ascii_letters + string.digits
print("Pf1-" + "".join(secrets.choice(chars) for _ in range(20)))'
}

# Azure
require az
export AZURE_CORE_ONLY_SHOW_ERRORS=true   # no preview warnings in the output

check_login() {
  az account show --output none 2>/dev/null \
    || die "Not logged in to Azure. Run: az login --use-device-code"
  if [[ -n "${AZURE_SUBSCRIPTION:-}" ]]; then
    az account set --subscription "$AZURE_SUBSCRIPTION"
  fi
}

subscription_id() { az account show --query id --output tsv; }

# One resource group per lab: deleting the group deletes everything in it
rg_name() { echo "rg-$(name "$1")"; }
# Regions this subscription may deploy to. Azure for Students and some new
# subscriptions get a policy such as "Allowed resource deployment regions"
# from Microsoft; prints nothing if there is no such restriction.
allowed_locations() {
  az policy assignment list --output json 2>/dev/null | python3 -c '
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
  status=$(az vm list-skus --location "$AZURE_LOCATION" --size "$size" \
      --resource-type virtualMachines --output json |
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
  az group create --name "$(rg_name "$1")" --location "$AZURE_LOCATION" \
    --tags "course=$COURSE_TAG" "lab=$1" --output none
}
delete_rg() {   # delete_rg <lab>
  local rg
  rg=$(rg_name "$1")
  if [[ "$(az group exists --name "$rg")" == "true" ]]; then
    log "Deleting resource group $rg with all resources (takes a few minutes) ..."
    az group delete --name "$rg" --yes
  else
    log "Resource group $rg does not exist."
  fi
}

# Storage account names: 3-24 lowercase letters and digits, globally unique
storage_name() { echo "${PREFIX}${OWNER}$(suffix)$1" | tr --complement --delete 'a-z0-9' | cut --characters 1-24; }

# Resource providers must be registered once per subscription
ensure_providers() {
  local ns state
  for ns in "$@"; do
    state=$(az provider show --name "$ns" --query registrationState --output tsv 2>/dev/null || echo NotRegistered)
    if [[ "$state" != "Registered" ]]; then
      log "Registering resource provider $ns ..."
      az provider register --name "$ns" --wait
    fi
  done
}

# Settings for tools/tofu.sh (the azurerm provider needs the subscription)
tofu_provider_vars() {
  export TF_VAR_location="$AZURE_LOCATION" ARM_SUBSCRIPTION_ID
  ARM_SUBSCRIPTION_ID="$(subscription_id)"
}
backend_key_arg() { echo "key=$1/terraform.tfstate"; }
