#!/usr/bin/env bash
# Create an Azure VM that installs and runs PlaceFinder via cloud-init.
# Usage: ./create-vm.sh [git ref]   (default ref: t01)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t02
ref="${1:-t01}"
size="${VM_SIZE:-Standard_B1s}"
check_login
check_repo_ref "$PLACEFINDER_REPO" "$ref"
check_vm_size "$size"
rg=$(rg_name "$LAB")
[[ "$(az group exists --name "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-vm.sh first."
[[ -f "$SSH_PUBLIC_KEY" ]] || die "SSH key $SSH_PUBLIC_KEY not found. Create it in the WSL shell, not in the dev container: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"

ip=$(my_ip)
ensure_rg "$LAB"

log "Creating network security group (SSH and port 8000 from $ip only) ..."
az network nsg create --resource-group "$rg" --name nsg-vm --output none
az network nsg rule create --resource-group "$rg" --nsg-name nsg-vm --name allow-ssh-api-from-my-ip \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes "$ip/32" --destination-port-ranges 22 8000 --output none

user_data=$(mktemp)
trap 'rm --force "$user_data"' EXIT
render "$(dirname "$0")/cloud-init.yaml" "REPO=$PLACEFINDER_REPO" "REF=$ref" >"$user_data"

# 64 GB Premium SSD (P6) is part of the free services of a new account
log "Creating VM $size with Ubuntu 24.04 (takes 1-2 minutes) ..."
public_ip=$(az vm create --resource-group "$rg" --name "$(name "$LAB-vm")" \
  --image Ubuntu2404 --size "$size" \
  --admin-username azureuser --ssh-key-values "$SSH_PUBLIC_KEY" \
  --custom-data "$user_data" \
  --nsg nsg-vm --public-ip-sku Standard \
  --os-disk-size-gb 64 --storage-sku Premium_LRS \
  --tags "course=$COURSE_TAG" "lab=$LAB" \
  --query publicIpAddress --output tsv) ||
  die "VM creation failed. On SkuNotAvailable set another VM_SIZE in config.env (e.g. Standard_B2ats_v2) or another AZURE_LOCATION, then run ./destroy-vm.sh and ./create-vm.sh again."
save_state "$LAB" PUBLIC_IP "$public_ip"

cat <<INFO

VM is running.
  SSH:          ssh azureuser@$public_ip
  cloud-init:   ssh azureuser@$public_ip cloud-init status --wait
  API:          http://$public_ip:8000/places?q=Erfurt
  Delete:       ./destroy-vm.sh
INFO
wait_for_http "http://$public_ip:8000/health" 600 || warn "Check the log on the VM: journalctl --unit placefinder"
