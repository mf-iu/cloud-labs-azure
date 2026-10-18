#!/usr/bin/env bash
# Create Azure Database for PostgreSQL 18 (Flexible Server, Burstable B1ms)
# that only accepts connections from your IP address. Daily backups and
# point-in-time recovery are always on; the backups are kept for seven days.
# Takes 5-10 minutes.
# Usage: ./create-db.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
ensure_providers Microsoft.DBforPostgreSQL
rg=$(rg_name "$LAB")
[[ "$(az group exists --name "$rg")" == "false" ]] || die "$rg exists already. Run ./destroy-db.sh first."
ensure_rg "$LAB"

ip=$(my_ip)
server=$(name "$(suffix)-$LAB-db")   # part of the global host name
password=$(random_password)

log "Creating server $server (PostgreSQL 18, Standard_B1ms, 32 GB) ..."
az postgres flexible-server create --resource-group "$rg" --name "$server" --location "$AZURE_LOCATION" \
  --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 18 \
  --admin-user pfadmin --admin-password "$password" \
  --public-access "$ip" --high-availability Disabled \
  --database-name placefinder \
  --tags "course=$COURSE_TAG" "lab=$LAB" --yes --output none

# Extensions have to be allow-listed on Azure before CREATE EXTENSION works
log "Allowing the extensions PostGIS and pg_trgm ..."
az postgres flexible-server parameter set --resource-group "$rg" --server-name "$server" \
  --name azure.extensions --value POSTGIS,PG_TRGM --output none

host=$(az postgres flexible-server show --resource-group "$rg" --name "$server" \
  --query fullyQualifiedDomainName --output tsv)
save_state "$LAB" DATABASE_URL "postgresql://pfadmin:$password@$host:5432/placefinder?sslmode=require"

cat <<INFO

Database ready: $host
  Load data:   ./load-cities.sh
  Queries:     ./query.sh       (interactive: ./query.sh --interactive)
  PlaceFinder: ./test-api.sh    (smoke test of t05 with this database)
  Backups:     ./backups.sh
  Delete:      ./destroy-db.sh  (or stop it: az postgres flexible-server stop --resource-group $rg --name $server)
The connection string is stored in .state/$LAB.env.
INFO
