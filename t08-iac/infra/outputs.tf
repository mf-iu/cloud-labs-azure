output "service_url" {
  description = "HTTPS endpoint of PlaceFinder"
  value       = "https://${azurerm_container_app.placefinder.ingress[0].fqdn}"
}

output "resource_group" {
  description = "For the deploy workflow (repository variable RESOURCE_GROUP)"
  value       = azurerm_resource_group.main.name
}

output "container_app" {
  description = "For the deploy workflow (repository variable CONTAINER_APP)"
  value       = azurerm_container_app.placefinder.name
}

output "storage_account" {
  value = azurerm_storage_account.data.name
}

output "database" {
  description = "Host name of PostgreSQL in the private DNS zone (only with enable_database = true)"
  value       = var.enable_database ? azurerm_postgresql_flexible_server.db[0].fqdn : null
}
