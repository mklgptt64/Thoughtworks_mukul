module "container_registry" {
  source              = "./modules/container_registry"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  prefix             = var.prefix
  acr_names           = ["quotes", "newsfeed", "frontend"]
}

resource "azurerm_user_assigned_identity" "identity_acr" {
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  name                = "identity-acr"
}

locals {
  acrs = { for name in module.container_registry.acr_names : name => module.container_registry.acr_ids[name] }
}

resource "random_uuid" "acrpull_ids" {
  for_each = local.acrs
  keepers = {
    acr_id = each.value
    sp_id  = azurerm_user_assigned_identity.identity_acr.principal_id
    role   = "AcrPull"
  }
}

data "azurerm_role_definition" "acrpull" {
  name = "AcrPull"
}

resource "azurerm_role_assignment" "acr_acrpull" {
  for_each = local.acrs
  name               = random_uuid.acrpull_ids[each.key].result
  scope              = each.value
  role_definition_id = data.azurerm_role_definition.acrpull.id
  principal_id       = azurerm_user_assigned_identity.identity_acr.principal_id
}

locals {
  acr_url = ".azurecr.io"
}

resource "local_file" "acr" {
  filename = "${path.module}/../acr-url.txt"
  content  = local.acr_url
}