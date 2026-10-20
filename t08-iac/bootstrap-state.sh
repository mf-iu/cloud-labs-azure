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

if ! az storage account show --resource-group "$rg" --name "$account" --output none 2>/dev/null; then
  log "Creating storage account $account for the state ..."
  az storage account create --resource-group "$rg" --name "$account" --location "$AZURE_LOCATION" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags "course=$COURSE_TAG" "lab=t08" --output none
  # Versioning keeps older states, e.g. after a failed apply
  az storage account blob-service-properties update --resource-group "$rg" --account-name "$account" \
    --enable-versioning true --output none
  az storage container create --account-name "$account" --name tfstate --auth-mode key \
    --account-key "$(az storage account keys list --resource-group "$rg" --name "$account" --query '[0].value' --output tsv)" --output none
fi

# Locking uses blob leases; OpenTofu reads the access key with your login
cat >"$STATE_DIR/backend.hcl" <<HCL
resource_group_name  = "$rg"
storage_account_name = "$account"
container_name       = "tfstate"
HCL
log "Wrote $STATE_DIR/backend.hcl. Next, in the repository root: tools/tofu.sh t08-iac/infra plan"
