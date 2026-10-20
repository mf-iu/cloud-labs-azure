# Object storage as in session 7 (t07-objektspeicher/create-storage.sh):
# storage account with a private container, CORS for the map and a
# lifecycle rule. Images stay on ghcr.io: an Azure Container Registry costs
# money every day, even unused (session 3).
resource "azurerm_storage_account" "data" {
  name                            = substr(replace("${local.name}${var.suffix}t08", "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  blob_properties {
    cors_rule {
      allowed_origins    = ["http://localhost:5173"]
      allowed_methods    = ["GET", "HEAD"]
      allowed_headers    = ["Range"]
      exposed_headers    = ["ETag", "Content-Length", "Content-Range"]
      max_age_in_seconds = 3600
    }
  }
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "data" {
  storage_account_id = azurerm_storage_account.data.id

  rule {
    name    = "expire-raw-data"
    enabled = true
    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["data/raw/"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}
