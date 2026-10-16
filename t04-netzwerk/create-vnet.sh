#!/usr/bin/env bash
# Create the PlaceFinder network design from session 4 on Azure:
# virtual network 10.20.0.0/16 with public, application and database
# subnets and one network security group (NSG) per subnet.
# Azure subnets span all availability zones of the region.
#
# Usage: ./create-vnet.sh [--with-vm] [--with-nat]
#   --with-vm   two test VMs: a bastion in the public subnet (SSH from your IP
#               only) and a VM without public address in the application
#               subnet (SSH only from the public subnet); check with ./check-vpc.sh
#   --with-nat  NAT gateway for the application subnet (about 1 EUR per day!)
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t04
with_vm=false
with_nat=false
for arg in "$@"; do
  case "$arg" in
    --with-vm) with_vm=true ;;
    --with-nat) with_nat=true ;;
    *) die "Unknown option: $arg" ;;
  esac
done
check_login
size="${VM_SIZE:-Standard_B1s}"
if $with_vm; then check_vm_size "$size"; fi
rg=$(rg_name "$LAB")
[[ "$(az group exists --name "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-vnet.sh first."
ensure_rg "$LAB"
clear_state "$LAB"   # values of an earlier run
vnet=$(name vnet)

rule() {   # rule <nsg> <name> <priority> <access> <source> <ports>
  az network nsg rule create --resource-group "$rg" --nsg-name "$1" --name "$2" --priority "$3" \
    --direction Inbound --access "$4" --protocol "*" \
    --source-address-prefixes "$5" --destination-port-ranges "$6" --output none
}

log "Creating network security groups ..."
for nsg in nsg-public nsg-app nsg-db; do
  az network nsg create --resource-group "$rg" --name "$nsg" --output none
done
rule nsg-public allow-https 100 Allow Internet 443
rule nsg-app allow-api-from-public 100 Allow 10.20.0.0/24 8000
rule nsg-db allow-postgres-from-app 100 Allow 10.20.10.0/24 5432
# The default rule AllowVnetInBound (65000) allows all traffic inside the
# virtual network. These rules close it for the app and database subnets.
rule nsg-app deny-other-vnet 4000 Deny VirtualNetwork "*"
rule nsg-db deny-other-vnet 4000 Deny VirtualNetwork "*"

log "Creating virtual network 10.20.0.0/16 with three subnets ..."
az network vnet create --resource-group "$rg" --name "$vnet" --address-prefixes 10.20.0.0/16 \
  --tags "course=$COURSE_TAG" "lab=$LAB" --output none
az network vnet subnet create --resource-group "$rg" --vnet-name "$vnet" --name public \
  --address-prefixes 10.20.0.0/24 --nsg nsg-public --output none
# Private subnets: no implicit internet access ("default outbound access")
az network vnet subnet create --resource-group "$rg" --vnet-name "$vnet" --name app \
  --address-prefixes 10.20.10.0/24 --nsg nsg-app --default-outbound false --output none
az network vnet subnet create --resource-group "$rg" --vnet-name "$vnet" --name db \
  --address-prefixes 10.20.20.0/24 --nsg nsg-db --default-outbound false --output none

if $with_nat; then
  warn "The NAT gateway costs about 0.05 USD per hour plus data. Delete it today!"
  az network public-ip create --resource-group "$rg" --name nat-ip --sku Standard --output none
  az network nat gateway create --resource-group "$rg" --name "$(name nat)" --public-ip-addresses nat-ip --output none
  az network vnet subnet update --resource-group "$rg" --vnet-name "$vnet" --name app --nat-gateway "$(name nat)" --output none
  save_state "$LAB" NAT true
fi

if $with_vm; then
  [[ -f "$SSH_PUBLIC_KEY" ]] || die "SSH key $SSH_PUBLIC_KEY not found. Create it in the WSL shell, not in the dev container: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
  rule nsg-public allow-ssh-from-my-ip 110 Allow "$(my_ip)/32" 22
  # before deny-other-vnet (4000): SSH into the app subnet only from the bastion's subnet
  rule nsg-app allow-ssh-from-public 110 Allow 10.20.0.0/24 22

  vm() {   # vm <name> <subnet> <query> <options for the public address...>; prints the queried value
    az vm create --resource-group "$rg" --name "$(name "$LAB-$1")" --image Ubuntu2404 \
      --size "$size" --admin-username azureuser --ssh-key-values "$SSH_PUBLIC_KEY" \
      --vnet-name "$vnet" --subnet "$2" --nsg "" "${@:4}" \
      --os-disk-size-gb 64 --storage-sku Premium_LRS \
      --tags "course=$COURSE_TAG" "lab=$LAB" --query "$3" --output tsv ||
      die "VM creation failed. On SkuNotAvailable set another VM_SIZE in config.env (e.g. Standard_B2ats_v2) or another AZURE_LOCATION, then run ./destroy-vnet.sh and try again."
  }
  log "Creating the bastion in subnet public and a private VM in subnet app ..."
  bastion_ip=$(vm bastion public publicIpAddress --public-ip-sku Standard)
  private_ip=$(vm private app privateIpAddress --public-ip-address "")
  save_state "$LAB" SSH_USER azureuser
  save_state "$LAB" BASTION_IP "$bastion_ip"
  save_state "$LAB" PRIVATE_IP "$private_ip"
  log "Bastion:    ssh azureuser@$bastion_ip"
  log "Private VM: ssh -J azureuser@$bastion_ip azureuser@$private_ip"
  log "Check both: ./check-vpc.sh"
fi

log "Network created. Overview:"
az network vnet subnet list --resource-group "$rg" --vnet-name "$vnet" \
  --query '[].{subnet:name, prefix:addressPrefix, nsg:networkSecurityGroup.id, natGateway:natGateway.id, defaultOutbound:defaultOutboundAccess}' \
  --output table
log "Delete everything with ./destroy-vnet.sh"
