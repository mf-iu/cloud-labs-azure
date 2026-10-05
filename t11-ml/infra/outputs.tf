output "service_url" {
  value = "https://${azurerm_container_app.estimate.ingress[0].fqdn}"
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "container_app" {
  value = azurerm_container_app.estimate.name
}

output "storage_account" {
  value = azurerm_storage_account.ml.name
}

output "model_uri" {
  value = "${azurerm_storage_account.ml.primary_blob_endpoint}${azurerm_storage_container.ml.name}/${var.model_path}"
}

output "mlflow_artifacts_destination" {
  value = "wasbs://${azurerm_storage_container.ml.name}@${azurerm_storage_account.ml.name}.blob.core.windows.net/mlflow"
}
