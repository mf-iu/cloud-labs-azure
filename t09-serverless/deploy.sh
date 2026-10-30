#!/usr/bin/env bash

# Create the infrastructure with OpenTofu and publish the function code
# with the Azure Functions Core Tools (remote build of the dependencies).
#
# Usage: ./deploy.sh [extra tofu arguments, e.g. -var database_url=...]

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

require func
check_login
tofu_sh="$REPO_ROOT/tools/tofu.sh"
infra="$REPO_ROOT/t09-serverless/infra"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# "$@" passes the arguments of this script on to tofu apply, e.g. -auto-approve
"$tofu_sh" "$infra" apply "$@"
# output -raw prints one output of the OpenTofu configuration without quotes
app=$("$tofu_sh" "$infra" output -raw function_app_name)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

log "Publishing the code to $app ..."
cd "$(dirname "$0")/function"
func azure functionapp publish "$app" --python
log "Done. Test it: ./invoke.sh [YYYY-MM-DD]"
