resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  location            = var.location
  resource_group_name = var.resource_group

  sku           = "Premium"
  admin_enabled = false
}