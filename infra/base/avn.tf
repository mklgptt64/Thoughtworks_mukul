module "virtual_network" {
  source              = "./modules/virtual_network"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  address_space       = ["10.5.0.0/16"]
  subnets             = ["public_subnet_a", "public_subnet_b"]
}

module "public_ips" {
  source              = "./modules/public_ip"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  ip_names            = ["public-ip-quotes", "public-ip-newsfeed", "public-ip-frontend"]
}

module "network_security_groups" {
  source              = "./modules/network_security_group"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  security_groups     = ["quotes", "newsfeed", "frontend"]
}

module "network_security_rules" {
  source              = "./modules/network_security_rule"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  security_rules = [
    { name = "rule-outbound-quotes", priority = 1000, direction = "Outbound", nsg = "quotes" },
    { name = "rule-outbound-newsfeed", priority = 1001, direction = "Outbound", nsg = "newsfeed" },
    { name = "rule-outbound-frontend", priority = 1002, direction = "Outbound", nsg = "frontend" },
    { name = "rule-inbound-ssh-quotes", priority = 1003, direction = "Inbound", nsg = "quotes", port = "22" },
    { name = "rule-inbound-ssh-newsfeed", priority = 1004, direction = "Inbound", nsg = "newsfeed", port = "22" },
    { name = "rule-inbound-ssh-frontend", priority = 1005, direction = "Inbound", nsg = "frontend", port = "22" },
    { name = "rule-inbound-quotes-8082", priority = 1006, direction = "Inbound", nsg = "quotes", port = "8082" },
    { name = "rule-inbound-newsfeed-8081", priority = 1007, direction = "Inbound", nsg = "newsfeed", port = "8081" },
    { name = "rule-inbound-frontend-8080", priority = 1008, direction = "Inbound", nsg = "frontend", port = "8080" }
  ]
}

module "network_interfaces" {
  source              = "./modules/network_interface"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  network_interfaces  = [
    { name = "network-interface-quotes", subnet = "public_subnet_a", public_ip = "public-ip-quotes", nsg = "quotes" },
    { name = "network-interface-newsfeed", subnet = "public_subnet_a", public_ip = "public-ip-newsfeed", nsg = "newsfeed" },
    { name = "network-interface-frontend", subnet = "public_subnet_b", public_ip = "public-ip-frontend", nsg = "frontend" }
  ]
}

module "route_table" {
  source              = "./modules/route_table"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  route_table_name    = "route-table"
  subnets            = ["public_subnet_a", "public_subnet_b"]
  routes = [
    { name = "default-route", address_prefix = "0.0.0.0/0", next_hop_type = "Internet" }
  ]
}
