#!/usr/bin/env bash
# Upload a trained model to the location that /estimate reads at start-up
# and start a new revision of the container app so that it loads the model.
# Usage: ./upload-model.sh <model.joblib>
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
model="${1:?Usage: $0 <model file>}"
tofu_out() { "$REPO_ROOT/tools/tofu.sh" "$REPO_ROOT/t11-ml/infra" output -raw "$1"; }
account=$(tofu_out storage_account)
model_uri=$(tofu_out model_uri)
blob="${model_uri#*.blob.core.windows.net/ml/}"

az storage blob upload --auth-mode login --account-name "$account" -c ml \
  -n "$blob" -f "$model" --overwrite -o none
log "Uploaded to $model_uri"

# A changed environment variable creates a new revision with fresh replicas
az containerapp update -g "$(tofu_out resource_group)" -n "$(tofu_out container_app)" \
  --set-env-vars "MODEL_UPLOADED=$(date -u +%Y%m%dT%H%M%SZ)" -o none
log "New revision started."
