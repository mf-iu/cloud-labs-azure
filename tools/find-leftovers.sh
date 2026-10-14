#!/usr/bin/env bash
# List course resource groups and resources that still exist, and costly
# resources without the course tag. Deletes nothing.
# Usage: tools/find-leftovers.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

check_login
section() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }

section "Resource groups tagged course=$COURSE_TAG"
az group list --tag "course=$COURSE_TAG" --query '[].{group:name, lab:tags.lab, location:location}' -o table
section "Resources in these groups"
az resource list --tag "course=$COURSE_TAG" --query '[].{name:name, type:type, group:resourceGroup}' -o table
section "All resource groups (also without tag)"
az group list --query '[].{group:name, location:location}' -o table

section "Costly resources in the subscription"
az vm list -d --query '[].{vm:name, group:resourceGroup, size:hardwareProfile.vmSize, state:powerState}' -o table
# disks without a VM (diskState Unattached) and snapshots cost storage;
# some CLI versions require -g for disk/snapshot list, so go by group
for g in $(az group list --query '[].name' -o tsv); do
  az disk list -g "$g" --query '[].{disk:name, group:resourceGroup, sizeGb:diskSizeGB, state:diskState}' -o table
  az snapshot list -g "$g" --query '[].{snapshot:name, group:resourceGroup, sizeGb:diskSizeGB}' -o table
done
az network nat gateway list --query '[].{natGateway:name, group:resourceGroup}' -o table
az network public-ip list --query '[].{publicIp:name, group:resourceGroup, ip:ipAddress}' -o table
az postgres flexible-server list --query '[].{server:name, group:resourceGroup, state:state}' -o table
az apim list --query '[].{apim:name, group:resourceGroup, sku:sku.name}' -o table
az containerapp list --query '[].{app:name, group:resourceGroup}' -o table
