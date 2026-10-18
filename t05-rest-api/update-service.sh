#!/usr/bin/env bash
# Roll out a new PlaceFinder version on the container app from t03: deploy
# $PLACEFINDER_IMAGE:<tag> by digest as a new revision, wait until it is
# ready and run the smoke test. Without a container app from t03, it creates
# one with ../t03-container/deploy.sh.
# Usage: ./update-service.sh [tag]   (default: t05)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
tag="${1:-t05}"
rg=$(rg_name t03)
app=$(name placefinder)

# A tag can later point to another image; the digest names exactly this one.
# Container Apps pulls the image from ghcr.io without credentials.
digest=$(public_image_digest "$PLACEFINDER_IMAGE:$tag") \
  || die "Cannot pull $PLACEFINDER_IMAGE:$tag without login: it does not exist or is private. Build it with ../t03-container/build-image.sh --push --tag $tag and make the package public on GitHub."
image="$PLACEFINDER_IMAGE@$digest"

if ! az containerapp show --resource-group "$rg" --name "$app" --output none 2>/dev/null; then
  log "No container app from t03; creating it with $image ..."
  "$REPO_ROOT/t03-container/deploy.sh" "$image"
else
  log "Updating $app to $image (new revision) ..."
  az containerapp update --resource-group "$rg" --name "$app" --image "$image" --output none
  # Single revision mode: the traffic moves to the new revision once it is ready
  log "Waiting until the new revision is ready ..."
  start=$SECONDS
  until az containerapp show --resource-group "$rg" --name "$app" \
      --query "properties.latestReadyRevisionName == properties.latestRevisionName" \
      --output tsv | grep --quiet --ignore-case '^true$'; do
    (( SECONDS - start < 600 )) || die "Revision not ready after 10 minutes: az containerapp revision list --resource-group $rg --name $app --output table"
    sleep 10
  done
  az containerapp revision list --resource-group "$rg" --name "$app" \
    --query '[].{revision:name, active:properties.active, traffic:properties.trafficWeight, image:properties.template.containers[0].image}' \
    --output table
fi
load_state t03
"$(dirname "$0")/smoke-test.sh" "$SERVICE_URL"
