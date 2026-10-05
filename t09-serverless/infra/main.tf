# Daily GeoNames update as Azure Function (Flex Consumption plan).
# The code is published separately: ../deploy.sh

locals {
  name = "${var.prefix}-${var.owner}-t09"
  tags = {
    course = "cloud-computing"
    lab    = "t09"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# One storage account: deployment package of the function and the data
resource "azurerm_storage_account" "main" {
  name                            = substr(replace("${local.name}${var.suffix}", "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "deploy" {
  name                  = "deploy"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Logs and metrics of the function (the first 5 GB per month are free)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "main" {
  name                = "${local.name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"
  tags                = local.tags
}

resource "azurerm_service_plan" "main" {
  name                = "${local.name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "sync" {
  name                = "${local.name}-${var.suffix}-geonames"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = local.tags

  runtime_name           = "python"
  runtime_version        = "3.12"
  maximum_instance_count = 40
  instance_memory_in_mb  = 512

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.deploy.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.main.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DATA_ACCOUNT_URL = azurerm_storage_account.main.primary_blob_endpoint
    DATA_CONTAINER   = azurerm_storage_container.data.name
    DATABASE_URL     = var.database_url
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }
}

# The function identity may write the change files ...
resource "azurerm_role_assignment" "function_data" {
  scope                = azurerm_storage_container.data.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.sync.identity[0].principal_id
}

# ... and so may you, for local tests with "func start" and for reading
resource "azurerm_role_assignment" "me_data" {
  scope                = azurerm_storage_container.data.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
