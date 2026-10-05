#!/usr/bin/env bash
# Create Azure Database for PostgreSQL (Flexible Server, Burstable B1ms)
# that only accepts connections from your IP address. Takes 5-10 minutes.
# Usage: ./create-db.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
ensure_providers Microsoft.DBforPostgreSQL
rg=$(rg_name "$LAB")
[[ "$(az group exists -n "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-db.sh first."
ensure_rg "$LAB"

ip=$(my_ip)
server=$(name "$(suffix)-$LAB-db")   # part of the global host name
password=$(random_password)

log "Creating server $server (PostgreSQL 17, Standard_B1ms, 32 GB) ..."
az postgres flexible-server create -g "$rg" -n "$server" -l "$AZURE_LOCATION" \
  --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 17 \
  --admin-user pfadmin --admin-password "$password" \
  --public-access "$ip" --high-availability Disabled \
  --database-name placefinder \
  --tags "course=$COURSE_TAG" "lab=$LAB" --yes -o none

# Extensions have to be allow-listed on Azure before CREATE EXTENSION works
log "Allowing the extensions PostGIS and pg_trgm ..."
az postgres flexible-server parameter set -g "$rg" --server-name "$server" \
  --name azure.extensions --value POSTGIS,PG_TRGM -o none

host=$(az postgres flexible-server show -g "$rg" -n "$server" \
  --query fullyQualifiedDomainName -o tsv)
save_state "$LAB" DATABASE_URL "postgresql://pfadmin:$password@$host:5432/placefinder?sslmode=require"

cat <<INFO

Database ready: $host
  Load data:   ./load-cities.sh
  Queries:     ./query.sh       (interactive: ./query.sh -i)
  Delete:      ./destroy-db.sh  (or stop it: az postgres flexible-server stop -g $rg -n $server)
The connection string is stored in .state/$LAB.env.
INFO
