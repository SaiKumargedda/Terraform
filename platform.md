# Part 2 – Platform Module

This module provisions the shared platform resources that AKS and your applications depend on.

## Folder Structure

```
modules/
   └── platform/
         ├── main.tf
         ├── variables.tf
         └── outputs.tf
```

---

## 1. Storage Account (Terraform Backend)

```hcl
resource "azurerm_storage_account" "storage" {

  name                     = var.storage_account_name

  resource_group_name      = var.resource_group_name

  location                 = var.location

  account_tier             = "Standard"

  account_replication_type = "LRS"

  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  blob_properties {

      versioning_enabled = true

      delete_retention_policy {

          days = 30

      }

  }

  tags = var.tags

}
```

---

## 2. Storage Container

```hcl
resource "azurerm_storage_container" "tfstate" {

  name                  = "tfstate"

  storage_account_name  = azurerm_storage_account.storage.name

  container_access_type = "private"

}
```

---

## 3. Log Analytics Workspace

```hcl
resource "azurerm_log_analytics_workspace" "law" {

  name                = var.log_analytics_name

  location            = var.location

  resource_group_name = var.resource_group_name

  sku                 = "PerGB2018"

  retention_in_days   = 30

}
```

---

## 4. Application Insights

```hcl
resource "azurerm_application_insights" "appi" {

  name                = var.appinsights_name

  location            = var.location

  resource_group_name = var.resource_group_name

  workspace_id        = azurerm_log_analytics_workspace.law.id

  application_type    = "web"

}
```

---

## 5. Azure Container Registry

```hcl
resource "azurerm_container_registry" "acr" {

  name                = var.acr_name

  resource_group_name = var.resource_group_name

  location            = var.location

  sku                 = "Premium"

  admin_enabled       = false

  public_network_access_enabled = false

}
```

---

## 6. Key Vault

```hcl
resource "azurerm_key_vault" "kv" {

  name                = var.keyvault_name

  location            = var.location

  resource_group_name = var.resource_group_name

  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name            = "standard"

  purge_protection_enabled   = true

  soft_delete_retention_days = 90

  public_network_access_enabled = false

}
```

---

## 7. Get Tenant Details

```hcl
data "azurerm_client_config" "current" {}
```

---

## 8. Key Vault Secret

```hcl
resource "azurerm_key_vault_secret" "dbpassword" {

  name = "db-password"

  value = var.db_password

  key_vault_id = azurerm_key_vault.kv.id

}
```

---

## 9. Private Endpoint for ACR

```hcl
resource "azurerm_private_endpoint" "acr" {

  name = "acr-private-endpoint"

  location = var.location

  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {

      name = "acr"

      private_connection_resource_id =
      azurerm_container_registry.acr.id

      subresource_names = [
          "registry"
      ]

      is_manual_connection = false

  }

}
```

---

## 10. Private Endpoint for Key Vault

```hcl
resource "azurerm_private_endpoint" "keyvault" {

  name = "kv-private-endpoint"

  location = var.location

  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {

      name = "keyvault"

      private_connection_resource_id =
      azurerm_key_vault.kv.id

      subresource_names = [
          "vault"
      ]

      is_manual_connection = false

  }

}
```

---

## 11. Private DNS Zone for ACR

```hcl
resource "azurerm_private_dns_zone" "acr" {

  name = "privatelink.azurecr.io"

  resource_group_name = var.resource_group_name

}
```

---

## 12. Private DNS Zone for Key Vault

```hcl
resource "azurerm_private_dns_zone" "kv" {

  name = "privatelink.vaultcore.azure.net"

  resource_group_name = var.resource_group_name

}
```

---

## 13. VNet Link

```hcl
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {

  name = "acr-link"

  private_dns_zone_name =
  azurerm_private_dns_zone.acr.name

  resource_group_name =
  var.resource_group_name

  virtual_network_id = var.vnet_id

}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {

  name = "kv-link"

  private_dns_zone_name =
  azurerm_private_dns_zone.kv.name

  resource_group_name =
  var.resource_group_name

  virtual_network_id = var.vnet_id

}
```

---

## 14. DNS Zone Group

```hcl
resource "azurerm_private_dns_zone_group" "acr" {

  name = "default"

  private_endpoint_id =
  azurerm_private_endpoint.acr.id

  private_dns_zone_configs {

      name = "acr"

      private_dns_zone_id =
      azurerm_private_dns_zone.acr.id

  }

}

resource "azurerm_private_dns_zone_group" "kv" {

  name = "default"

  private_endpoint_id =
  azurerm_private_endpoint.keyvault.id

  private_dns_zone_configs {

      name = "kv"

      private_dns_zone_id =
      azurerm_private_dns_zone.kv.id

  }

}
```

---

## variables.tf

```hcl
variable "location" {}

variable "resource_group_name" {}

variable "storage_account_name" {}

variable "log_analytics_name" {}

variable "appinsights_name" {}

variable "acr_name" {}

variable "keyvault_name" {}

variable "db_password" {
  sensitive = true
}

variable "private_endpoint_subnet_id" {}

variable "vnet_id" {}

variable "tags" {
  type = map(string)
}
```

---

## outputs.tf

```hcl
output "acr_id" {

  value = azurerm_container_registry.acr.id

}

output "acr_login_server" {

  value = azurerm_container_registry.acr.login_server

}

output "keyvault_id" {

  value = azurerm_key_vault.kv.id

}

output "loganalytics_id" {

  value = azurerm_log_analytics_workspace.law.id

}

output "application_insights_key" {

  value = azurerm_application_insights.appi.instrumentation_key

  sensitive = true

}
```
