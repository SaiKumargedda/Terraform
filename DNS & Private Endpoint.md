# Part 6 – Azure Public DNS Module

This module connects your custom domain to Azure Front Door.

## Folder Structure

```
modules/
   └── dns/
         ├── main.tf
         ├── variables.tf
         └── outputs.tf
```

---

## 1. Public DNS Zone

```hcl
resource "azurerm_dns_zone" "dns" {

  name                = var.domain_name

  resource_group_name = var.resource_group_name

  tags = var.tags

}
```

---

## 2. CNAME Record

```hcl
resource "azurerm_dns_cname_record" "www" {

  name                = "www"

  zone_name           = azurerm_dns_zone.dns.name

  resource_group_name = var.resource_group_name

  ttl = 300

  record = var.frontdoor_endpoint

}
```

Example:

```
www.company.com
        │
        ▼
frontend.azurefd.net
```

---

## 3. Root Domain (Alias A Record)

If you want `company.com` instead of `www.company.com`:

```hcl
resource "azurerm_dns_a_record" "root" {

  name                = "@"

  zone_name           = azurerm_dns_zone.dns.name

  resource_group_name = var.resource_group_name

  ttl = 300

  target_resource_id = var.frontdoor_profile_id

}
```

---

## 4. TXT Record (Domain Validation)

```hcl
resource "azurerm_dns_txt_record" "validation" {

  name = "_dnsauth"

  zone_name = azurerm_dns_zone.dns.name

  resource_group_name = var.resource_group_name

  ttl = 300

  record {

      value = var.validation_token

  }

}
```

Azure Front Door verifies domain ownership using this TXT record.

---

## 5. MX Record

```hcl
resource "azurerm_dns_mx_record" "mail" {

  name = "@"

  zone_name = azurerm_dns_zone.dns.name

  resource_group_name = var.resource_group_name

  ttl = 3600

  record {

      preference = 10

      exchange = "mail.company.com"

  }

}
```

---

## 6. CAA Record

```hcl
resource "azurerm_dns_caa_record" "caa" {

  name = "@"

  zone_name = azurerm_dns_zone.dns.name

  resource_group_name = var.resource_group_name

  ttl = 3600

  record {

      flags = 0

      tag = "issue"

      value = "digicert.com"

  }

}
```

---

## 7. Diagnostic Settings

```hcl
resource "azurerm_monitor_diagnostic_setting" "dns" {

  name = "dns-diagnostics"

  target_resource_id =
  azurerm_dns_zone.dns.id

  log_analytics_workspace_id =
  var.loganalytics_id

  metric {

      category = "AllMetrics"

  }

}
```

---

## variables.tf

```hcl
variable "domain_name" {}

variable "resource_group_name" {}

variable "frontdoor_endpoint" {}

variable "frontdoor_profile_id" {}

variable "validation_token" {}

variable "loganalytics_id" {}

variable "tags" {

  type = map(string)

}
```

---

## outputs.tf

```hcl
output "dns_zone_id" {

  value = azurerm_dns_zone.dns.id

}

output "dns_name_servers" {

  value = azurerm_dns_zone.dns.name_servers

}
```

---

## terraform.tfvars

```hcl
domain_name = "company.com"
```

---

## DNS Flow

```
User
     │
     ▼
www.company.com
     │
     ▼
ISP DNS Resolver
     │
     ▼
Root DNS
     │
     ▼
.com
     │
     ▼
Azure DNS Zone
     │
     ▼
CNAME
     │
     ▼
frontend.azurefd.net
     │
     ▼
Azure Front Door
     │
     ▼
Application Gateway
     │
     ▼
AKS
     │
     ▼
Pod
```

## Root Domain Flow

```
company.com
     │
     ▼
Azure DNS
     │
     ▼
Alias A Record
     │
     ▼
Azure Front Door
     │
     ▼
Application Gateway
     │
     ▼
AKS
```

---

## Interview Questions

**Why use a CNAME?**

Because Front Door provides a hostname such as `frontend.azurefd.net`. Instead of exposing that hostname to users, we map `www.company.com` to it using a CNAME.

**Why use an Alias A Record?**

The root domain (`company.com`) cannot always use a standard CNAME due to DNS rules. Azure supports Alias A Records that point directly to Azure resources like Azure Front Door.

**Why is TTL set to 300?**

```
TTL = 300 seconds
```

This allows DNS changes to propagate relatively quickly during migrations or failovers while avoiding excessive DNS queries.

**Why do we need the TXT record?**

Azure Front Door requires proof that you own the domain before issuing a managed TLS certificate. The TXT record is used for domain validation.

---

## Current Architecture

```
User
   │
   ▼
Azure DNS Zone
   │
   ├── A Record (@)
   │
   ├── CNAME (www)
   │
   ├── TXT (_dnsauth)
   │
   ├── MX
   │
   └── CAA
        │
        ▼
Azure Front Door
        │
        ▼
Application Gateway
        │
        ▼
AKS
        │
        ▼
Pods
```

---
---

# Part 7 – Private DNS & Private Endpoints Module

This module is used for private communication between AKS and Azure PaaS services such as:

- Azure Key Vault
- Azure Container Registry (ACR)
- Azure Storage
- Azure SQL

## Folder Structure

```
modules/
   └── private-link/
          ├── main.tf
          ├── variables.tf
          └── outputs.tf
```

---

## 1. Private DNS Zone (Key Vault)

```hcl
resource "azurerm_private_dns_zone" "kv" {

  name                = "privatelink.vaultcore.azure.net"

  resource_group_name = var.resource_group_name

}
```

---

## 2. Private DNS Zone (ACR)

```hcl
resource "azurerm_private_dns_zone" "acr" {

  name                = "privatelink.azurecr.io"

  resource_group_name = var.resource_group_name

}
```

---

## 3. Private DNS Zone (Storage)

```hcl
resource "azurerm_private_dns_zone" "storage" {

  name                = "privatelink.blob.core.windows.net"

  resource_group_name = var.resource_group_name

}
```

---

## 4. Private DNS Zone (SQL)

```hcl
resource "azurerm_private_dns_zone" "sql" {

  name                = "privatelink.database.windows.net"

  resource_group_name = var.resource_group_name

}
```

---

## 5. VNet Link (Key Vault)

```hcl
resource "azurerm_private_dns_zone_virtual_network_link" "kv" {

  name = "kv-link"

  resource_group_name = var.resource_group_name

  private_dns_zone_name =
  azurerm_private_dns_zone.kv.name

  virtual_network_id = var.vnet_id

}
```

---

## 6. VNet Link (ACR)

```hcl
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {

  name = "acr-link"

  resource_group_name = var.resource_group_name

  private_dns_zone_name =
  azurerm_private_dns_zone.acr.name

  virtual_network_id = var.vnet_id

}
```

---

## 7. Private Endpoint (Key Vault)

```hcl
resource "azurerm_private_endpoint" "kv" {

  name = "kv-private-endpoint"

  location = var.location

  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {

      name = "keyvault"

      private_connection_resource_id =
      var.keyvault_id

      subresource_names = [
          "vault"
      ]

      is_manual_connection = false

  }

}
```

---

## 8. Private Endpoint (ACR)

```hcl
resource "azurerm_private_endpoint" "acr" {

  name = "acr-private-endpoint"

  location = var.location

  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {

      name = "acr"

      private_connection_resource_id =
      var.acr_id

      subresource_names = [
          "registry"
      ]

      is_manual_connection = false

  }

}
```

---

## 9. Private Endpoint (Storage)

```hcl
resource "azurerm_private_endpoint" "storage" {

  name = "storage-private-endpoint"

  location = var.location

  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {

      name = "storage"

      private_connection_resource_id =
      var.storage_account_id

      subresource_names = [
          "blob"
      ]

      is_manual_connection = false

  }

}
```

---

## 10. Private Endpoint (SQL)

```hcl
resource "azurerm_private_endpoint" "sql" {

  name = "sql-private-endpoint"

  location = var.location

  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {

      name = "sql"

      private_connection_resource_id =
      var.sql_server_id

      subresource_names = [
          "sqlServer"
      ]

      is_manual_connection = false

  }

}
```

---

## 11. DNS Zone Group (Key Vault)

```hcl
resource "azurerm_private_dns_zone_group" "kv" {

  name = "default"

  private_endpoint_id =
  azurerm_private_endpoint.kv.id

  private_dns_zone_configs {

      name = "kv"

      private_dns_zone_id =
      azurerm_private_dns_zone.kv.id

  }

}
```

---

## 12. DNS Zone Group (ACR)

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
```

---

## variables.tf

```hcl
variable "location" {}

variable "resource_group_name" {}

variable "vnet_id" {}

variable "private_endpoint_subnet_id" {}

variable "keyvault_id" {}

variable "acr_id" {}

variable "storage_account_id" {}

variable "sql_server_id" {}
```

---

## outputs.tf

```hcl
output "keyvault_private_endpoint" {

  value =
  azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address

}

output "acr_private_endpoint" {

  value =
  azurerm_private_endpoint.acr.private_service_connection[0].private_ip_address

}
```

---

## Complete Private Flow

```
AKS Pod
     │
     ▼
CoreDNS
     │
     ▼
Private DNS Zone
     │
     ▼
Private DNS Record
     │
     ▼
Private Endpoint
     │
     ▼
Azure Backbone
     │
     ▼
Azure Key Vault
```

## ACR Flow

```
AKS Node
     │
     ▼
myacr.azurecr.io
     │
     ▼
Private DNS
     │
     ▼
10.0.4.5
     │
     ▼
Private Endpoint
     │
     ▼
Azure Container Registry
```

## Key Vault Flow

```
Application
     │
     ▼
mykv.vault.azure.net
     │
     ▼
Private DNS
     │
     ▼
10.0.4.6
     │
     ▼
Private Endpoint
     │
     ▼
Key Vault
```

---

## Interview Questions

**Why do we need a Private DNS Zone?**

Without it, the service hostname (for example, `myvault.vault.azure.net`) resolves to the public IP. With a Private DNS Zone linked to the VNet, it resolves to the Private Endpoint IP.

**Why do we create a DNS Zone Group?**

The DNS Zone Group automatically creates and maintains the DNS records that map the Azure service hostname to the Private Endpoint IP address.

**Why is the Private Endpoint in a separate subnet?**

In many enterprise environments, Private Endpoints are placed in a dedicated subnet to simplify network security, routing, IP management, and governance.

---

## Enterprise Flow

```
Internet User
      │
      ▼
Azure Front Door
      │
      ▼
Application Gateway
      │
      ▼
AKS
      │
      ├────────► Private Endpoint (ACR)
      │
      ├────────► Private Endpoint (Key Vault)
      │
      ├────────► Private Endpoint (Storage)
      │
      └────────► Private Endpoint (SQL)
```
