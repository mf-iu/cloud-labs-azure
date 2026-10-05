terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
  }

  # Remote state in Azure Blob Storage; see .state/backend.hcl
  backend "azurerm" {}
}

# The subscription comes from ARM_SUBSCRIPTION_ID (set by tools/tofu.sh).
# Resource providers are registered once by t01-grundlagen/register-providers.sh.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
