output "service_url" {
  description = "HTTPS endpoint of PlaceFinder"
  value       = "https://${azurerm_container_app.placefinder.ingress[0].fqdn}"
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "container_app" {
  value = azurerm_container_app.placefinder.name
}

output "storage_account" {
  value = azurerm_storage_account.data.name
}

output "database_url" {
  description = "Connection string (only with enable_database = true)"
  value = var.enable_database ? format("postgresql://pfadmin:%s@%s:5432/placefinder?sslmode=require",
  random_password.db[0].result, azurerm_postgresql_flexible_server.db[0].fqdn) : null
  sensitive = true
}
