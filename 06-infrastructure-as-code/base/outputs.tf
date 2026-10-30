# Read by service (terraform_remote_state) and later configurations

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output "resource_group" {
  value = azurerm_resource_group.main.name
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output "location" {
  value = azurerm_resource_group.main.location
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output "app_subnet_id" {
  description = "Subnet delegated to the Container Apps environment"
  value       = azurerm_subnet.app.id
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output "db_subnet_id" {
  description = "Subnet delegated to PostgreSQL Flexible Server"
  value       = azurerm_subnet.db.id
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output "storage_account" {
  value = azurerm_storage_account.data.name
}
