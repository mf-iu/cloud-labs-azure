#!/usr/bin/env bash
# Create the PlaceFinder network design from session 4 on Azure:
# virtual network 10.20.0.0/16 with public, application and database
# subnets and one network security group (NSG) per subnet.
# Azure subnets span all availability zones of the region.
#
# Usage: ./create-vnet.sh [--with-vm] [--with-nat]
#   --with-vm   test VM in the public subnet (SSH from your IP only)
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
rg=$(rg_name "$LAB")
[[ "$(az group exists -n "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-vnet.sh first."
ensure_rg "$LAB"
vnet=$(name vnet)

rule() {   # rule <nsg> <name> <priority> <access> <source> <ports>
  az network nsg rule create -g "$rg" --nsg-name "$1" -n "$2" --priority "$3" \
    --direction Inbound --access "$4" --protocol "*" \
    --source-address-prefixes "$5" --destination-port-ranges "$6" -o none
}

log "Creating network security groups ..."
for nsg in nsg-public nsg-app nsg-db; do
  az network nsg create -g "$rg" -n "$nsg" -o none
done
rule nsg-public allow-https 100 Allow Internet 443
rule nsg-app allow-api-from-public 100 Allow 10.20.0.0/24 8000
rule nsg-db allow-postgres-from-app 100 Allow 10.20.10.0/24 5432
# The default rule AllowVnetInBound (65000) allows all traffic inside the
# virtual network. These rules close it for the app and database subnets.
rule nsg-app deny-other-vnet 4000 Deny VirtualNetwork "*"
rule nsg-db deny-other-vnet 4000 Deny VirtualNetwork "*"

log "Creating virtual network 10.20.0.0/16 with three subnets ..."
az network vnet create -g "$rg" -n "$vnet" --address-prefixes 10.20.0.0/16 \
  --tags "course=$COURSE_TAG" "lab=$LAB" -o none
az network vnet subnet create -g "$rg" --vnet-name "$vnet" -n public \
  --address-prefixes 10.20.0.0/24 --nsg nsg-public -o none
# Private subnets: no implicit internet access ("default outbound access")
az network vnet subnet create -g "$rg" --vnet-name "$vnet" -n app \
  --address-prefixes 10.20.10.0/24 --nsg nsg-app --default-outbound false -o none
az network vnet subnet create -g "$rg" --vnet-name "$vnet" -n db \
  --address-prefixes 10.20.20.0/24 --nsg nsg-db --default-outbound false -o none

if $with_nat; then
  warn "The NAT gateway costs about 0.05 USD per hour plus data. Delete it today!"
  az network public-ip create -g "$rg" -n nat-ip --sku Standard -o none
  az network nat gateway create -g "$rg" -n "$(name nat)" --public-ip-addresses nat-ip -o none
  az network vnet subnet update -g "$rg" --vnet-name "$vnet" -n app --nat-gateway "$(name nat)" -o none
fi

if $with_vm; then
  [[ -f "$SSH_PUBLIC_KEY" ]] || die "SSH key $SSH_PUBLIC_KEY not found."
  rule nsg-public allow-ssh-from-my-ip 110 Allow "$(my_ip)/32" 22
  public_ip=$(az vm create -g "$rg" -n "$(name "$LAB-vm")" --image Ubuntu2404 \
    --size Standard_B1s --admin-username azureuser --ssh-key-values "$SSH_PUBLIC_KEY" \
    --vnet-name "$vnet" --subnet public --nsg "" --public-ip-sku Standard \
    --os-disk-size-gb 64 --storage-sku Premium_LRS \
    --query publicIpAddress -o tsv)
  log "Test VM: ssh azureuser@$public_ip"
fi

log "Network created. Overview:"
az network vnet subnet list -g "$rg" --vnet-name "$vnet" \
  --query '[].{subnet:name, prefix:addressPrefix, nsg:networkSecurityGroup.id, natGateway:natGateway.id, defaultOutbound:defaultOutboundAccess}' \
  -o table
log "Delete everything with ./destroy-vnet.sh"
