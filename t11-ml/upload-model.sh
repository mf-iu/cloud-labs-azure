#!/usr/bin/env bash

# Upload a trained model to the location that /estimate reads at start-up
# and start a new revision of the container app so that it loads the model.
#
# Usage: ./upload-model.sh <model.joblib>

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
# ${1:?text} stops the script with this text if there is no first argument
model="${1:?Usage: $0 <model file>}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

tofu_out() {
    # output -raw prints one output of the OpenTofu configuration without quotes
    "$REPO_ROOT/tools/tofu.sh" "$REPO_ROOT/t11-ml/infra" output -raw "$1"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

account=$(tofu_out storage_account)
model_uri=$(tofu_out model_uri)
# ${x#*text} removes everything up to and including text: the name of the blob
# in the container ml
blob="${model_uri#*.blob.core.windows.net/ml/}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

az storage blob upload --auth-mode login --account-name "$account" --container-name ml \
    --name "$blob" --file "$model" --overwrite --output none
log "Uploaded to $model_uri"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# A changed environment variable creates a new revision with fresh replicas
# A changed environment variable makes Container Apps start a new revision,
# which loads the new model
az containerapp update --resource-group "$(tofu_out resource_group)" --name "$(tofu_out container_app)" \
    --set-env-vars "MODEL_UPLOADED=$(date --utc +%Y%m%dT%H%M%SZ)" --output none
log "New revision started."
