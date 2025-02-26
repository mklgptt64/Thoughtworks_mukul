locals {
  # Subnets definition
  subnets = [
    { name = "public_subnet_a", address_prefix = "10.5.0.0/24" },
    { name = "public_subnet_b", address_prefix = "10.5.1.0/24" }
  ]
  
  # Public IPs names and their corresponding resources
  public_ips = [
    { name = "public-ip-quotes", allocation_method = "Dynamic" },
    { name = "public-ip-newsfeed", allocation_method = "Dynamic" },
    { name = "public-ip-frontend", allocation_method = "Dynamic" }
  ]

  # Network Security Groups (NSGs)
  nsgs = [
    "security-group-quotes",
    "security-group-newsfeed",
    "security-group-frontend"
  ]
  
  # Network Security Rules for inbound and outbound
  security_rules = [
    # Outbound rules
    { name = "rule-outbound-quotes", priority = 1000, direction = "Outbound", nsg = "security-group-quotes" },
    { name = "rule-outbound-newsfeed", priority = 1001, direction = "Outbound", nsg = "security-group-newsfeed" },
    { name = "rule-outbound-frontend", priority = 1002, direction = "Outbound", nsg = "security-group-frontend" },

    # Inbound SSH rules
    { name = "rule-inbound-ssh-quotes", priority = 1003, direction = "Inbound", port = "22", nsg = "security-group-quotes" },
    { name = "rule-inbound-ssh-newsfeed", priority = 1004, direction = "Inbound", port = "22", nsg = "security-group-newsfeed" },
    { name = "rule-inbound-ssh-frontend", priority = 1005, direction = "Inbound", port = "22", nsg = "security-group-frontend" },

    # Inbound application port rules
    { name = "rule-inbound-quotes-8082", priority = 1006, direction = "Inbound", port = "8082", nsg = "security-group-quotes" },
    { name = "rule-inbound-newsfeed-8081", priority = 1007, direction = "Inbound", port = "8081", nsg = "security-group-newsfeed" },
    { name = "rule-inbound-frontend-8080", priority = 1008, direction = "Inbound", port = "8080", nsg = "security-group-frontend" }
  ]
}

resource "azurerm_virtual_network" "virtual-network" {
  name                = "virtual-network"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  address_space       = ["10.5.0.0/16"]
}

# Subnets creation using for_each
resource "azurerm_subnet" "subnets" {
  for_each            = { for subnet in local.subnets : subnet.name => subnet }
  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  virtual_network_name = azurerm_virtual_network.virtual-network.name
  address_prefixes    = [each.value.address_prefix]
}

# Public IPs creation using for_each
resource "azurerm_public_ip" "public_ips" {
  for_each            = { for ip in local.public_ips : ip.name => ip }
  name                = each.value.name
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = azurerm_virtual_network.virtual-network.location
  allocation_method   = each.value.allocation_method
}

# Route table for public subnets
resource "azurerm_route_table" "route-table" {
  name                          = "route-table"
  location                      = azurerm_virtual_network.virtual-network.location
  resource_group_name           = azurerm_virtual_network.virtual-network.resource_group_name

  route {
    name           = "route"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = {
    environment = "Production"
  }
}

# Subnet route table association using for_each
resource "azurerm_subnet_route_table_association" "subnet_association" {
  for_each            = { for subnet in azurerm_subnet.subnets : subnet.id => subnet }
  subnet_id           = each.key
  route_table_id      = azurerm_route_table.route-table.id
}

# NSG creation using for_each
resource "azurerm_network_security_group" "nsgs" {
  for_each            = toset(local.nsgs)
  name                = each.value
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

# Security rules creation using for_each
resource "azurerm_network_security_rule" "security_rules" {
  for_each            = { for rule in local.security_rules : rule.name => rule }
  name                = each.value.name
  priority            = each.value.priority
  direction           = each.value.direction
  access              = "Allow"
  protocol            = "Tcp"
  source_port_range   = "*"
  destination_port_range = each.value.port != null ? each.value.port : "*"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.nsgs[each.value.nsg].name
  resource_group_name = data.azurerm_resource_group.azure-resource.name
}

# Network Interface creation using for_each
resource "azurerm_network_interface" "network_interfaces" {
  for_each            = { for idx, ip in local.public_ips : ip.name => {
    name         = "network-interface-${ip.name}"
    subnet       = local.subnets[idx % length(local.subnets)].name
    public_ip    = ip.name
    network_security_group = local.nsgs[idx % length(local.nsgs)]
  }}
  
  name                = each.value.name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.azure-resource.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[each.value.subnet].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ips[each.value.public_ip].id
  }

  network_security_group_id = azurerm_network_security_group.nsgs[each.value.network_security_group].id
}

# NIC and NSG association using for_each
resource "azurerm_network_interface_security_group_association" "nic_sg_association" {
  for_each = azurerm_network_interface.network_interfaces
  
  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.nsgs[each.value.network_security_group].id
}
