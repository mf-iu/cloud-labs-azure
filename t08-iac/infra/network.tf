# The network design of session 4 (t04-netzwerk/create-vnet.sh): VNet
# 10.20.0.0/16 with an application and a database subnet. Both are delegated
# to the service that runs in them; the public entry point is the load
# balancer of the Container Apps environment, so no public subnet is needed.
locals {
  name = "${var.prefix}-${var.owner}"
  tags = {
    course = "cloud-computing"
    lab    = "t08"
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

# The Container Apps environment needs a subnet of its own (at least /27).
# Outbound access stays on: the replicas pull the image from ghcr.io. In
# production, a NAT gateway would take over (about 1 EUR per day).
resource "azurerm_subnet" "app" {
  name                            = "app"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = ["10.20.10.0/24"]
  default_outbound_access_enabled = true

  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# PostgreSQL Flexible Server with private access: only in this subnet,
# without any public address
resource "azurerm_subnet" "db" {
  name                            = "db"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = ["10.20.20.0/24"]
  default_outbound_access_enabled = false

  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Firewall of the database subnet as in session 4: PostgreSQL only from the
# application subnet, nothing else from within the VNet
resource "azurerm_network_security_group" "db" {
  name                = "nsg-db"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  security_rule {
    name                       = "allow-postgres-from-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.20.10.0/24"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "5432"
  }

  security_rule {
    name                       = "deny-other-vnet"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}
