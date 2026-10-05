#!/usr/bin/env bash
# Create the storage account for the OpenTofu state (blob versioning,
# private container) and write .state/backend.hcl for tools/tofu.sh.
# Usage: ./bootstrap-state.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
ensure_providers Microsoft.Storage
rg=$(rg_name tfstate)
account=$(storage_name tfstate)
ensure_rg tfstate

if ! az storage account show -g "$rg" -n "$account" -o none 2>/dev/null; then
  log "Creating storage account $account for the state ..."
  az storage account create -g "$rg" -n "$account" -l "$AZURE_LOCATION" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags "course=$COURSE_TAG" "lab=t08" -o none
  # Versioning keeps older states, e.g. after a failed apply
  az storage account blob-service-properties update -g "$rg" --account-name "$account" \
    --enable-versioning true -o none
  az storage container create --account-name "$account" -n tfstate --auth-mode key \
    --account-key "$(az storage account keys list -g "$rg" -n "$account" --query '[0].value' -o tsv)" -o none
fi

# Locking uses blob leases; OpenTofu reads the access key with your login
cat >"$STATE_DIR/backend.hcl" <<HCL
resource_group_name  = "$rg"
storage_account_name = "$account"
container_name       = "tfstate"
HCL
log "Wrote $STATE_DIR/backend.hcl. Next: ../tools/tofu.sh infra plan"
