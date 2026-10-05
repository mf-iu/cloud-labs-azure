# Lab t11: storage for MLflow artifacts and models, PlaceFinder with the
# /estimate endpoint on Azure Container Apps. The app reads the model with
# its managed identity.

locals {
  name = "${var.prefix}-${var.owner}-t11"
  tags = {
    course = "cloud-computing"
    lab    = "t11"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "ml" {
  name                            = substr(replace("${local.name}${var.suffix}", "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "ml" {
  name                  = "ml"
  storage_account_id    = azurerm_storage_account.ml.id
  container_access_type = "private"
}

resource "azurerm_container_app_environment" "main" {
  name                = "${local.name}-env"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_container_app" "estimate" {
  name                         = "${local.name}-estimate"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type = "SystemAssigned"
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "placefinder"
      image  = "${var.placefinder_image}:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "MODEL_URI"
        value = "${azurerm_storage_account.ml.primary_blob_endpoint}${azurerm_storage_container.ml.name}/${var.model_path}"
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

# The app may read the models, you may write them (MLflow, upload-model.sh)
resource "azurerm_role_assignment" "app" {
  scope                = azurerm_storage_container.ml.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_container_app.estimate.identity[0].principal_id
}

resource "azurerm_role_assignment" "me" {
  scope                = azurerm_storage_account.ml.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
