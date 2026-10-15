#!/usr/bin/env bash
# List course resource groups and resources that still exist, and costly
# resources without the course tag. Deletes nothing.
# Usage: tools/find-leftovers.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
section() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }

section "Resource groups tagged course=$COURSE_TAG"
az group list --tag "course=$COURSE_TAG" --query '[].{group:name, lab:tags.lab, location:location}' --output table
section "Resources in these groups"
az resource list --tag "course=$COURSE_TAG" --query '[].{name:name, type:type, group:resourceGroup}' --output table
section "All resource groups (also without tag)"
az group list --query '[].{group:name, location:location}' --output table

section "Costly resources in the subscription"
az vm list --show-details --query '[].{vm:name, group:resourceGroup, size:hardwareProfile.vmSize, state:powerState}' --output table
# disks without a VM (diskState Unattached) and snapshots cost storage;
# some CLI versions require --resource-group for disk/snapshot list, so go by group
for g in $(az group list --query '[].name' --output tsv); do
  az disk list --resource-group "$g" --query '[].{disk:name, group:resourceGroup, sizeGb:diskSizeGB, state:diskState}' --output table
  az snapshot list --resource-group "$g" --query '[].{snapshot:name, group:resourceGroup, sizeGb:diskSizeGB}' --output table
done
az network nat gateway list --query '[].{natGateway:name, group:resourceGroup}' --output table
az network public-ip list --query '[].{publicIp:name, group:resourceGroup, ip:ipAddress}' --output table
az postgres flexible-server list --query '[].{server:name, group:resourceGroup, state:state}' --output table
az apim list --query '[].{apim:name, group:resourceGroup, sku:sku.name}' --output table
az containerapp list --query '[].{app:name, group:resourceGroup}' --output table
