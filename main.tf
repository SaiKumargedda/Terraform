resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location_primary
}

module "acr" {
  source = "./modules/acr"
  acr_name       = "globalacr123"
  location       = var.location_primary
  resource_group = azurerm_resource_group.main.name
}

module "keyvault" {
  source = "./modules/keyvault"
  kv_name        = "global-kv-123"
  location       = var.location_primary
  resource_group = azurerm_resource_group.main.name
}