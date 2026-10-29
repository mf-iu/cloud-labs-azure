# The outputs of base: resource group, network and storage. base stays until
# the end of the course; service is created and destroyed in the session.
data "terraform_remote_state" "base" {
  backend = "azurerm"
  config  = merge(var.backend, { key = "06-infrastructure-as-code/base/terraform.tfstate" })
}

locals {
  name = "${var.prefix}-${var.owner}"
  base = data.terraform_remote_state.base.outputs
  tags = {
    course = "cloud-computing"
    lab    = "t08"
  }
}
