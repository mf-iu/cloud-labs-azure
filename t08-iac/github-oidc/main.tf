# Keyless deployment from GitHub Actions: the workflow exchanges its OIDC
# token for an Entra ID token of the managed identity below (no secrets).
# Run t08-iac/infra first; the identity may change only that resource group.

locals {
  name = "${var.prefix}-${var.owner}"
  tags = {
    course = "cloud-computing"
    lab    = "t08"
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "target" {
  name = "rg-${local.name}-t08"
}

resource "azurerm_resource_group" "cicd" {
  name     = "rg-${local.name}-cicd"
  location = var.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "github" {
  name                = "${local.name}-github-deploy"
  resource_group_name = azurerm_resource_group.cicd.name
  location            = azurerm_resource_group.cicd.location
  tags                = local.tags
}

# Trust: only this repository and branch, not forks or pull requests
resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-${var.github_branch}"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
}

# Permission: manage resources in the resource group of t08-iac/infra only
resource "azurerm_role_assignment" "deploy" {
  scope                = data.azurerm_resource_group.target.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}
