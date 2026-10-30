terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
  }

  # Remote state in Azure Blob Storage; storage account and key come from
  # tools/tofu.sh (.state/backend.hcl, written by ../bootstrap-state.sh)
  backend "azurerm" {}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The subscription comes from ARM_SUBSCRIPTION_ID (set by tools/tofu.sh).
# Resource providers are registered once by 01-account/register-providers.sh.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
