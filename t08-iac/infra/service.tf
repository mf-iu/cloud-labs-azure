# PlaceFinder on Azure Container Apps as in session 3, now in the
# application subnet of the VNet. The environment with the workload profile
# "Consumption" is billed per use and scales to zero; its public load
# balancer is the only way in. The CI pipeline of PlaceFinder pushes the
# images to ghcr.io; the deploy workflow (deploy.example.yml) rolls out new
# versions.
resource "azurerm_container_app_environment" "main" {
  name                               = "${local.name}-t08-env"
  resource_group_name                = azurerm_resource_group.main.name
  location                           = azurerm_resource_group.main.location
  infrastructure_subnet_id           = azurerm_subnet.app.id
  infrastructure_resource_group_name = "rg-${local.name}-t08-env" # created and deleted by Azure
  tags                               = local.tags
  # No Log Analytics workspace: logs are only streamed (az containerapp logs show)

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

locals {
  # with a database: connection string without password, the password comes
  # from a secret of the container app as PGPASSWORD (libpq reads it);
  # DATABASE_INIT loads the places from the image into the empty database
  database_env = var.enable_database ? {
    DATABASE_URL  = "postgresql://pfadmin@${azurerm_postgresql_flexible_server.db[0].fqdn}:5432/placefinder?sslmode=require"
    DATABASE_INIT = "true"
  } : {}
}

resource "azurerm_container_app" "placefinder" {
  name                         = "${local.name}-t08-placefinder"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  dynamic "secret" {
    for_each = var.enable_database ? [1] : []
    content {
      name  = "pgpassword"
      value = random_password.db[0].result
    }
  }

  template {
    min_replicas = 0
    max_replicas = var.max_replicas

    container {
      name   = "placefinder"
      image  = "${var.placefinder_image}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      dynamic "env" {
        for_each = local.database_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.enable_database ? [1] : []
        content {
          name        = "PGPASSWORD"
          secret_name = "pgpassword"
        }
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

  # The deploy workflow sets new images; without this, the next apply would
  # roll back to image_tag (drift between pipeline and OpenTofu)
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
