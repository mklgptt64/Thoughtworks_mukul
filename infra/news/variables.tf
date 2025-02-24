variable "prefix" {
  default = "news4321"
}

variable "location" {
  default = "East US"
}

variable "acr_url_default" {
  default = ".azurecr.io"
}

variable "keyvault_name" {
  description = "Name of the Azure Key Vault storing sensitive data"
  default     = "news4321-keyvault"
}