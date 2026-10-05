# Resource group and network from lab t04

locals {
  name = "${var.prefix}-${var.owner}"
  tags = {
    course = "cloud-computing"
    lab    = "t08"
  }
  subnets = {
    public = { cidr = "10.20.0.0/24", private = false }
    app    = { cidr = "10.20.10.0/24", private = true }
    db     = { cidr = "10.20.20.0/24", private = true }
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}-t08"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${local.name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                            = each.key
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [each.value.cidr]
  default_outbound_access_enabled = !each.value.private
}

resource "azurerm_network_security_group" "this" {
  for_each = local.subnets

  name                = "nsg-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

locals {
  # subnet, name, priority, access, source, port
  rules = [
    ["public", "allow-https", 100, "Allow", "Internet", "443"],
    ["app", "allow-api-from-public", 100, "Allow", "10.20.0.0/24", "8000"],
    ["db", "allow-postgres-from-app", 100, "Allow", "10.20.10.0/24", "5432"],
    ["app", "deny-other-vnet", 4000, "Deny", "VirtualNetwork", "*"],
    ["db", "deny-other-vnet", 4000, "Deny", "VirtualNetwork", "*"],
  ]
}

resource "azurerm_network_security_rule" "this" {
  for_each = { for r in local.rules : "${r[0]}-${r[1]}" => r }

  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.this[each.value[0]].name
  name                        = each.value[1]
  priority                    = each.value[2]
  access                      = each.value[3]
  direction                   = "Inbound"
  protocol                    = "*"
  source_address_prefix       = each.value[4]
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = each.value[5]
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
