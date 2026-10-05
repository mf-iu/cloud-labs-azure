# PlaceFinder on Azure Container Apps, scales to zero when idle

resource "azurerm_container_app_environment" "main" {
  name                = "${local.name}-env"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
  # No Log Analytics workspace: logs are only streamed (az containerapp logs show)
}

resource "azurerm_container_app" "placefinder" {
  name                         = "${local.name}-placefinder"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "placefinder"
      image  = "${var.placefinder_image}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DATA_ACCOUNT_URL"
        value = azurerm_storage_account.data.primary_blob_endpoint
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
