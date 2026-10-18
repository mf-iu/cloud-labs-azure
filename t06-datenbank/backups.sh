#!/usr/bin/env bash
# Show the automated backups of the PostgreSQL server: retention, backups and
# the time span of a point-in-time restore. Changes nothing.
# Usage: ./backups.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/provider.sh"

LAB=t06
check_login
rg=$(rg_name "$LAB")
[[ "$(az group exists --name "$rg")" == "true" ]] || die "No database. Run ./create-db.sh first."
server=$(az postgres flexible-server list --resource-group "$rg" --query '[0].name' --output tsv)
[[ -n "$server" ]] || die "No server in $rg. Run ./create-db.sh first."

log "Backup settings of $server:"
az postgres flexible-server show --resource-group "$rg" --name "$server" \
  --query '{RetentionDays: backup.backupRetentionDays, GeoRedundant: backup.geoRedundantBackup, EarliestRestore: backup.earliestRestoreDate}' \
  --output table

log "Backups (the first right after creation, then one a day):"
az postgres flexible-server backup list --resource-group "$rg" --server-name "$server" \
  --query '[].{Name: name, Type: backupType, Completed: completedTime}' --output table

earliest=$(az postgres flexible-server show --resource-group "$rg" --name "$server" \
  --query backup.earliestRestoreDate --output tsv)
[[ -n "$earliest" ]] || { warn "No restore window yet. Try again in a few minutes."; exit 0; }
cat <<INFO

Point-in-time restore possible from $earliest until a few minutes ago:
the backups plus the WAL, which the server archives every five minutes.
Data written after the latest restore point would be lost (RPO: up to five minutes).
A restore creates a new server with a new host name (RTO: several minutes plus the
switch of the application). Not done here, it would cost a second server:
  az postgres flexible-server restore --resource-group $rg --name $server-restored \\
    --source-server $server --restore-time <time, e.g. $(date --utc +%Y-%m-%dT%H:%M:00Z)>
INFO
