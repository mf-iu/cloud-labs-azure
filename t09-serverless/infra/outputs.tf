output "function_app_name" {
  value = azurerm_function_app_flex_consumption.sync.name
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "storage_account" {
  value = azurerm_storage_account.main.name
}

output "data_account_url" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
