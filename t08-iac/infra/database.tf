# Optional PostgreSQL (enable_database = true). Reachable only from
# admin_cidrs; connecting the container app is part of the exercise.

resource "random_password" "db" {
  count   = var.enable_database ? 1 : 0
  length  = 24
  special = false
}

resource "azurerm_postgresql_flexible_server" "db" {
  count                  = var.enable_database ? 1 : 0
  name                   = "${local.name}-${var.suffix}-t08-db"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "17"
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768
  administrator_login    = "pfadmin"
  administrator_password = random_password.db[0].result
  backup_retention_days  = 7
  tags                   = local.tags

  # Azure picks a zone; keep it stable instead of moving the server
  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "placefinder" {
  count     = var.enable_database ? 1 : 0
  name      = "placefinder"
  server_id = azurerm_postgresql_flexible_server.db[0].id
}

# Allow-list the extensions before CREATE EXTENSION
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  count     = var.enable_database ? 1 : 0
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.db[0].id
  value     = "POSTGIS,PG_TRGM"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "admin" {
  for_each = var.enable_database ? toset(var.admin_cidrs) : toset([])

  name             = "admin-${replace(replace(each.value, ".", "-"), "/", "_")}"
  server_id        = azurerm_postgresql_flexible_server.db[0].id
  start_ip_address = cidrhost(each.value, 0)
  end_ip_address   = cidrhost(each.value, -1)
}
