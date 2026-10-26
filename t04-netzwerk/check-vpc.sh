#!/usr/bin/env bash
# Compare the network with the design of session 4 (part 1): address ranges,
# network security groups and internet access of the three subnets, rules of
# the network security groups. With the test VMs of --with-vm, also check
# what is reachable from where (part 2): the bastion in the public subnet
# reaches the internet, the private VM only through the bastion and the
# internet only with --with-nat.
# Usage: ./check-vpc.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t04
check_login
load_state "$LAB"
rg=$(rg_name "$LAB")
vnet=$(name vnet)
[[ "$(az group exists --name "$rg")" == true ]] || die "No network. Create it with ./create-vnet.sh first."
nat="${NAT:-false}"

results=() failed=0
check() {   # check <description> <expected> <actual>
  local mark=ok
  [[ "$2" == "$3" ]] || { mark=UNEXPECTED; failed=1; }
  results+=("$(printf '%-10s %-40s expected: %-22s got: %s' "$mark" "$1" "$2" "${3:-(nothing)}")")
}
joined() { local lines; lines=$(sort); echo "${lines//$'\n'/, }"; }   # stdin lines -> "a, b"

# ---------------------------------------------------------------- part 1: design
log "Design 1/2: subnets, their network security group and internet access ..."
subnet() {   # subnet <name> <query>
  az network vnet subnet show --resource-group "$rg" --vnet-name "$vnet" --name "$1" \
    --query "$2" --output tsv
}
internet() {   # internet <subnet>: NAT gateway, none or default outbound access
  if [[ -n "$(subnet "$1" natGateway.id)" ]]; then
    echo "NAT gateway"
  elif [[ "$(subnet "$1" defaultOutboundAccess)" == false ]]; then
    echo none
  else
    echo "default outbound access"
  fi
}
app_access=none
[[ "$nat" != true ]] || app_access="NAT gateway"
for entry in public:10.20.0.0/24 app:10.20.10.0/24 db:10.20.20.0/24; do
  s=${entry%%:*}
  nsg=$(subnet "$s" networkSecurityGroup.id)
  check "Subnet $s: address range" "${entry#*:}" "$(subnet "$s" addressPrefix)"
  check "Subnet $s: network security group" "nsg-$s" "${nsg##*/}"
done
# The public subnet reaches the internet through public addresses of its VMs
check "Subnet app: internet access" "$app_access" "$(internet app)"
check "Subnet db: internet access" none "$(internet db)"

log "Design 2/2: incoming rules of the network security groups (without SSH) ..."
rules() {   # rules <nsg> <Allow|Deny>: incoming rules as "port from source"
  az network nsg rule list --resource-group "$rg" --nsg-name "$1" \
    --query "[?direction=='Inbound' && access=='$2'].[destinationPortRange || join(',', destinationPortRanges), sourceAddressPrefix || join(',', sourceAddressPrefixes)]" \
    --output tsv |
    while read -r port source; do
      [[ "$port" == 22 ]] || echo "$port from $source"   # SSH rules of the test VMs
    done | joined
}
check "nsg-public: allowed" "443 from Internet" "$(rules nsg-public Allow)"
check "nsg-app: allowed" "8000 from 10.20.0.0/24" "$(rules nsg-app Allow)"
check "nsg-db: allowed" "5432 from 10.20.10.0/24" "$(rules nsg-db Allow)"
check "nsg-app: denied" "* from VirtualNetwork" "$(rules nsg-app Deny)"
check "nsg-db: denied" "* from VirtualNetwork" "$(rules nsg-db Deny)"

# ---------------------------------------------------------------- part 2: reachability
if [[ -z "${BASTION_IP:-}" || -z "${PRIVATE_IP:-}" ]]; then
  log "No test VMs: reachability not checked (optional: create the network with --with-vm)."
else
  require ssh nc
  # Own known_hosts file: the cloud reuses addresses, and ~/.ssh stays clean
  opts=(-i "${SSH_PUBLIC_KEY%.pub}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10
        -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/$LAB.known_hosts")
  # shellcheck disable=SC2029  # the commands are meant to run on the VM
  bastion() { ssh "${opts[@]}" "$SSH_USER@$BASTION_IP" "$@"; }
  # ProxyCommand instead of -J, so that the options apply to both connections
  # shellcheck disable=SC2029
  private() {
    ssh "${opts[@]}" -o ProxyCommand="ssh ${opts[*]} -W %h:%p $SSH_USER@$BASTION_IP" \
      "$SSH_USER@$PRIVATE_IP" "$@"
  }
  # HTTP status of a well-known website, 000 if there is no connection
  probe='curl --silent --output /dev/null --max-time 8 --write-out "%{http_code}" https://www.openstreetmap.org/ || true'
  answers() { [[ "$1" =~ ^[23][0-9][0-9]$ ]] && echo yes || echo no; }
  wait_for_ssh() {   # wait_for_ssh <bastion|private>; the VMs need a minute after creation
    local _
    for _ in $(seq 18); do
      "$1" true 2>/dev/null && return 0
      sleep 10
    done
    "$1" true
  }

  log "Reachability 1/4: bastion $BASTION_IP, SSH from here, internet through the gateway ..."
  wait_for_ssh bastion \
    || die "No SSH connection to $BASTION_IP. Has your IP address changed? It is now $(my_ip)."
  check "Bastion reaches the internet" yes "$(answers "$(bastion "$probe")")"

  log "Reachability 2/4: private VM $PRIVATE_IP through the bastion ..."
  if wait_for_ssh private; then reachable=yes; else reachable=no; fi
  check "Private VM reachable through bastion" yes "$reachable"

  if [[ "$reachable" == yes ]]; then
    log "Reachability 3/4: private VM, name resolution and internet (only with --with-nat) ..."
    private "getent hosts www.openstreetmap.org" || warn "No DNS answer on the private VM"
    expected=no
    [[ "$nat" != true ]] || expected=yes
    check "Private VM reaches the internet" "$expected" "$(answers "$(private "$probe")")"
  fi

  log "Reachability 4/4: private VM directly from here (private address, no route to it) ..."
  if nc -z -w 5 "$PRIVATE_IP" 22 2>/dev/null; then direct=yes; else direct=no; fi
  check "Private VM reachable directly from here" no "$direct"
fi

echo
printf '%s\n' "${results[@]}"
(( failed == 0 )) || die "Some results differ from the network design."
log "The network matches the design."
