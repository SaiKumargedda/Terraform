# Enterprise Root Module – Folder Structure & Composition

This is the root configuration that wires together all modules (networking, platform, aks, application-gateway, frontdoor, dns, private-link, monitoring) into a complete enterprise deployment.

## Folder Structure

```
terraform/
│
├── backend.tf
├── providers.tf
├── versions.tf
├── variables.tf
├── outputs.tf
├── main.tf
├── terraform.tfvars
│
├── modules/
│      ├── networking/
│      ├── platform/
│      ├── aks/
│      ├── application-gateway/
│      ├── frontdoor/
│      ├── dns/
│      ├── private-link/
│      └── monitoring/
│
└── environments/
       ├── dev
       ├── qa
       └── prod
```

---

## versions.tf

```hcl
terraform {

  required_version = ">=1.6"

  required_providers {

    azurerm = {

      source = "hashicorp/azurerm"

      version = "~>4.0"

    }

  }

}
```

---

## providers.tf

```hcl
provider "azurerm" {

  features {}

  subscription_id = var.subscription_id

}
```

---

## backend.tf

```hcl
terraform {

  backend "azurerm" {

    resource_group_name  = "rg-tfstate"

    storage_account_name = "tfstate001"

    container_name       = "tfstate"

    key                  = "prod.tfstate"

  }

}
```

---

## main.tf

### Networking

```hcl
module "networking" {

  source = "./modules/networking"

  resource_group_name = var.resource_group_name

  location = var.location

  subscription_id = var.subscription_id

  vnet_name = var.vnet_name

  tags = var.tags

}
```

### Platform

```hcl
module "platform" {

  source = "./modules/platform"

  location = var.location

  resource_group_name = var.resource_group_name

  vnet_id =
  module.networking.vnet_id

  private_endpoint_subnet_id =
  module.networking.private_endpoint_subnet_id

  storage_account_name = var.storage_account_name

  acr_name = var.acr_name

  keyvault_name = var.keyvault_name

  log_analytics_name = var.loganalytics_name

  appinsights_name = var.appinsights_name

  db_password = var.db_password

  tags = var.tags

}
```

### AKS

```hcl
module "aks" {

  source = "./modules/aks"

  cluster_name = var.cluster_name

  location = var.location

  resource_group_name = var.resource_group_name

  aks_subnet_id =
  module.networking.aks_subnet_id

  log_analytics_workspace_id =
  module.platform.loganalytics_id

  acr_id =
  module.platform.acr_id

  keyvault_id =
  module.platform.keyvault_id

  action_group_id =
  module.monitoring.action_group_id

  kubernetes_version =
  var.kubernetes_version

  tags = var.tags

}
```

### Application Gateway

```hcl
module "application_gateway" {

  source = "./modules/application-gateway"

  location = var.location

  resource_group_name = var.resource_group_name

  appgw_subnet_id =
  module.networking.appgw_subnet_id

  application_gateway_id =
  module.aks.aks_id

  keyvault_id =
  module.platform.keyvault_id

  loganalytics_id =
  module.platform.loganalytics_id

  tags = var.tags

}
```

### Front Door

```hcl
module "frontdoor" {

  source = "./modules/frontdoor"

  resource_group_name = var.resource_group_name

  frontdoor_name = var.frontdoor_name

  central_appgw_fqdn =
  module.application_gateway.public_dns

  south_appgw_fqdn =
  module.application_gateway.dr_public_dns

  loganalytics_id =
  module.platform.loganalytics_id

  tags = var.tags

}
```

### DNS

```hcl
module "dns" {

  source = "./modules/dns"

  domain_name = var.domain_name

  resource_group_name = var.resource_group_name

  frontdoor_endpoint =
  module.frontdoor.frontdoor_endpoint

  frontdoor_profile_id =
  module.frontdoor.frontdoor_profile_id

  validation_token =
  var.validation_token

  loganalytics_id =
  module.platform.loganalytics_id

  tags = var.tags

}
```

### Private Link

```hcl
module "private_link" {

  source = "./modules/private-link"

  location = var.location

  resource_group_name = var.resource_group_name

  vnet_id =
  module.networking.vnet_id

  private_endpoint_subnet_id =
  module.networking.private_endpoint_subnet_id

  acr_id =
  module.platform.acr_id

  keyvault_id =
  module.platform.keyvault_id

  storage_account_id =
  module.platform.storage_account_id

  sql_server_id =
  var.sql_server_id

}
```

### Monitoring

```hcl
module "monitoring" {

  source = "./modules/monitoring"

  resource_group_name = var.resource_group_name

  email = var.email

  aks_id =
  module.aks.aks_id

  application_gateway_id =
  module.application_gateway.application_gateway_id

  firewall_id =
  module.networking.firewall_id

  frontdoor_id =
  module.frontdoor.frontdoor_profile_id

  storage_account_id =
  module.platform.storage_account_id

  acr_id =
  module.platform.acr_id

  keyvault_id =
  module.platform.keyvault_id

  loganalytics_id =
  module.platform.loganalytics_id

  logicapp_url =
  var.logicapp_url

}
```

---

## variables.tf

Contains variables like:

- `subscription_id`
- `resource_group_name`
- `location`
- `vnet_name`
- `cluster_name`
- `domain_name`
- `frontdoor_name`
- `storage_account_name`
- `acr_name`
- `keyvault_name`
- `email`
- `logicapp_url`
- `tags`

---

## terraform.tfvars

```hcl
subscription_id = "xxxxxxxx"

location = "Central India"

resource_group_name = "rg-prod"

cluster_name = "aks-prod"

domain_name = "company.com"

frontdoor_name = "fd-prod"

vnet_name = "vnet-prod"

storage_account_name = "tfstateprod"

acr_name = "companyacr"

keyvault_name = "companykv"

email = "devops@company.com"

kubernetes_version = "1.31"
```

---

## Deployment Order

```
Terraform Init
     │
     ▼
Terraform Plan
     │
     ▼
Terraform Apply
     │
     ▼
Networking
     │
     ▼
Platform
     │
     ▼
AKS
     │
     ▼
Application Gateway
     │
     ▼
Front Door
     │
     ▼
DNS
     │
     ▼
Private Link
     │
     ▼
Monitoring
     │
     ▼
Application Ready
```

---

## Complete Enterprise Flow

```
Developer
     │
     ▼
Azure DevOps
     │
     ▼
Terraform
     │
     ▼
Resource Group
     │
     ▼
VNet
     │
     ▼
Subnets
     │
     ▼
Firewall
     │
     ▼
Storage
     │
     ▼
Key Vault
     │
     ▼
ACR
     │
     ▼
AKS
     │
     ▼
Application Gateway
     │
     ▼
Azure Front Door
     │
     ▼
DNS
     │
     ▼
Private Endpoint
     │
     ▼
Azure Monitor
     │
     ▼
Production
```
