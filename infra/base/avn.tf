locals {
  # Define subnet names and public IP names
  subnets = ["public_subnet_a", "public_subnet_b"]
  public_ip_names = ["public-ip-quotes", "public-ip-newsfeed", "public-ip-frontend"]
  nsg_names = ["quotes", "newsfeed", "frontend"]

  # Network security rules for inbound and outbound traffic
  security_rules = [
    # Outbound rules
    { name = "rule-outbound-quotes", priority = 1000, direction = "Outbound", port = "*", nsg = "quotes" },
    { name = "rule-outbound-newsfeed", priority = 1001, direction = "Outbound", port = "*", nsg = "newsfeed" },
    { name = "rule-outbound-frontend", priority = 1002, direction = "Outbound", port = "*", nsg = "frontend" },

    # Inbound SSH rules
    { name = "rule-inbound-ssh-quotes", priority = 1003, direction = "Inbound", port = "22", nsg = "quotes" },
    { name = "rule-inbound-ssh-newsfeed", priority = 1004, direction = "Inbound", port = "22", nsg = "newsfeed" },
    { name = "rule-inbound-ssh-frontend", priority = 1005, direction = "Inbound", port = "22", nsg = "frontend" },

    # Inbound application port rules
    { name = "rule-inbound-quotes-8082", priority = 1006, direction = "Inbound", port = "8082", nsg = "quotes" },
    { name = "rule-inbound-newsfeed-8081", priority = 1007, direction = "Inbound", port = "8081", nsg = "newsfeed" },
    { name = "rule-inbound-frontend-8080", priority = 1008, direction = "Inbound", port = "8080", nsg = "frontend" }
  ]
}

module "virtual_network" {
  source              = "./modules/virtual_network"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  address_space       = ["10.5.0.0/16"]
  subnets             = local.subnets
}

module "public_ips" {
  source              = "./modules/public_ip"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  ip_names            = local.public_ip_names
}

module "network_security_groups" {
  source              = "./modules/network_security_group"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  security_groups     = local.nsg_names
}

module "network_security_rules" {
  source              = "./modules/network_security_rule"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  security_rules      = local.security_rules
}

module "network_interfaces" {
  source              = "./modules/network_interface"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  network_interfaces  = [
    for idx, nsg in local.nsg_names : {
      name      = "network-interface-${nsg}"
      subnet    = local.subnets[idx % length(local.subnets)] # Distribute NICs across subnets
      public_ip = local.public_ip_names[idx]
      nsg       = nsg
    }
  ]
}

module "route_table" {
  source              = "./modules/route_table"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  route_table_name    = "route-table"
  subnets             = local.subnets
  routes = [
    { name = "default-route", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
  ]
}
