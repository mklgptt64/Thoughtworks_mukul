###############
# MODULE: Storage with Security Enhancements
###############

resource "azurerm_storage_account" "public-storage-account" {
  name                     = "${var.prefix}psa"
  resource_group_name      = data.azurerm_resource_group.azure-resource.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids  = [
      azurerm_subnet.public_subnet_a.id,  # Allowing only Subnet A
      azurerm_subnet.public_subnet_b.id   # Allowing Subnet B as well
    ]
  }

  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
}

resource "azurerm_storage_container" "public-storage-container" {
  name                  = "${var.prefix}psc"
  storage_account_name  = azurerm_storage_account.public-storage-account.name
  container_access_type = "private" # Changed to private for security
}

resource "azurerm_storage_blob" "blob-static" {
  name                   = "static"
  storage_account_name   = azurerm_storage_account.public-storage-account.name
  storage_container_name = azurerm_storage_container.public-storage-container.name
  type                   = "Block"
}

# Private Endpoint for Secure Access
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "storage-private-endpoint"
  resource_group_name = data.azurerm_resource_group.azure-resource.name
  location            = var.location
  subnet_id           = azurerm_subnet.public_subnet_a.id  # Using Subnet A for Private Endpoint

  private_service_connection {
    name                           = "storage-private-connection"
    private_connection_resource_id = azurerm_storage_account.public-storage-account.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

output "url_blob" {
  value = "https://${azurerm_storage_account.public-storage-account.name}.blob.core.windows.net/${azurerm_storage_container.public-storage-container.name}/static/"
}