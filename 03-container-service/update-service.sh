#!/usr/bin/env bash

# Roll out a new PlaceFinder version on the container app from t03: deploy
# $PLACEFINDER_IMAGE:<tag> by digest as a new revision, wait until it is
# ready and run the smoke test. Without a container app from t03, it creates
# one with ./deploy.sh.
#
# Usage: ./update-service.sh [tag]   (default: t05)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source "$(dirname "$0")/../lib/provider.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

require_github_user   # PLACEFINDER_IMAGE and PLACEFINDER_REPO need it

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_login
tag="${1:-t05}"
rg=$(rg_name t03)
app=$(name placefinder)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# A tag can later point to another image; the digest names exactly this one.
# Container Apps pulls the image from ghcr.io without credentials.
# The digest (sha256:...) of the image on ghcr.io; image@digest names exactly
# this image, even if the tag moves later
digest=$(public_image_digest "$PLACEFINDER_IMAGE:$tag") \
    || die "Cannot pull $PLACEFINDER_IMAGE:$tag without login: it does not exist or is private. Build it with /workspaces/cloud-labs-local/02-container/publish-image.sh --tag $tag and make the package public on GitHub."
image="$PLACEFINDER_IMAGE@$digest"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# --output none: only the exit code tells whether the app exists
if ! az containerapp show --resource-group "$rg" --name "$app" --output none 2>/dev/null; then
    log "No container app from t03; creating it with $image ..."
    "$REPO_ROOT/03-container-service/deploy.sh" "$image"
else
    log "Updating $app to $image (new revision) ..."
    az containerapp update --resource-group "$rg" --name "$app" --image "$image" --output none
    # Single revision mode: the traffic moves to the new revision once it is ready
    log "Waiting until the new revision is ready ..."
    start=$SECONDS
    # The query compares two fields and prints true or false; repeat every 10
    # seconds until it is true
    until az containerapp show --resource-group "$rg" --name "$app" \
            --query "properties.latestReadyRevisionName == properties.latestRevisionName" \
            --output tsv | grep --quiet --ignore-case '^true$'; do
        (( SECONDS - start < 600 )) || die "Revision not ready after 10 minutes: az containerapp revision list --resource-group $rg --name $app --output table"
        sleep 10
    done
    # --query builds a table row with named columns from each revision
    # (JMESPath)
    az containerapp revision list --resource-group "$rg" --name "$app" \
        --query '[].{revision:name, active:properties.active, traffic:properties.trafficWeight, image:properties.template.containers[0].image}' \
        --output table
fi
# SERVICE_URL from the state of deploy.sh
load_state t03
# The smoke test wrapper next to this script
"$(dirname "$0")/smoke-test.sh" "$SERVICE_URL"
