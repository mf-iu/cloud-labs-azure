# Data lake for lab t10: GeoParquet in Blob Storage, queried with DuckDB

locals {
  name = "${var.prefix}-${var.owner}-t10"
  tags = {
    course = "cloud-computing"
    lab    = "t10"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# Hierarchical namespace turns Blob Storage into Data Lake Storage Gen2
resource "azurerm_storage_account" "lake" {
  name                            = substr(replace("${local.name}${var.suffix}", "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "lake" {
  name                  = "lake"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

# DuckDB and "az storage --auth-mode login" use your Entra ID login
resource "azurerm_role_assignment" "me" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
