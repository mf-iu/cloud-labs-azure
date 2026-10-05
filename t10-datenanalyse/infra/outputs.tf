output "storage_account" {
  value = azurerm_storage_account.lake.name
}

output "container" {
  value = azurerm_storage_container.lake.name
}
