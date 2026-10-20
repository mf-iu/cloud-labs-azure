# Optional PostgreSQL (enable_database = true) with private access: in the
# delegated database subnet, found by name through a private DNS zone,
# without any public address. Unlike session 6, it cannot be loaded from
# your computer; PlaceFinder loads the places itself at startup
# (DATABASE_INIT, service.tf).

resource "random_password" "db" {
  count   = var.enable_database ? 1 : 0
  length  = 24
  special = false
}

resource "azurerm_private_dns_zone" "db" {
  count               = var.enable_database ? 1 : 0
  name                = "${local.name}-${var.suffix}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  count               = var.enable_database ? 1 : 0
  name                = "vnet"
  private_dns_zone_id = azurerm_private_dns_zone.db[0].id
  virtual_network_id  = azurerm_virtual_network.main.id
  tags                = local.tags
}

resource "azurerm_postgresql_flexible_server" "db" {
  count                         = var.enable_database ? 1 : 0
  name                          = "${local.name}-${var.suffix}-t08-db"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "18" # as in session 6
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  administrator_login           = "pfadmin"
  administrator_password        = random_password.db[0].result # also in the state!
  backup_retention_days         = 7
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.db[0].id
  public_network_access_enabled = false
  tags                          = local.tags

  # Azure picks a zone; keep it instead of moving the server
  lifecycle {
    ignore_changes = [zone]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_postgresql_flexible_server_database" "placefinder" {
  count     = var.enable_database ? 1 : 0
  name      = "placefinder"
  server_id = azurerm_postgresql_flexible_server.db[0].id
}

# Allow-list the extensions before CREATE EXTENSION (PlaceFinder runs it)
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  count     = var.enable_database ? 1 : 0
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.db[0].id
  value     = "POSTGIS,PG_TRGM"
}
