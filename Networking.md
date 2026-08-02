# Part 1 – Networking Module

## Folder Structure

```
terraform/
│
├── modules/
│   └── networking/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── providers.tf
│       ├── versions.tf
│       ├── main.tf
│       └── terraform.tfvars
```

---

## versions.tf

```hcl
terraform {

  required_version = ">=1.6.0"

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
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

    key                  = "dev.terraform.tfstate"

  }

}
```

---

## modules/networking/main.tf

### Resource Group

```hcl
resource "azurerm_resource_group" "rg" {

  name     = var.resource_group_name

  location = var.location

  tags = var.tags

}
```

### Virtual Network

```hcl
resource "azurerm_virtual_network" "vnet" {

  name                = var.vnet_name

  location            = azurerm_resource_group.rg.location

  resource_group_name = azurerm_resource_group.rg.name

  address_space = [
      "10.0.0.0/16"
  ]

  tags = var.tags

}
```

### AKS Subnet

```hcl
resource "azurerm_subnet" "aks" {

  name = "aks-subnet"

  resource_group_name = azurerm_resource_group.rg.name

  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = [
      "10.0.1.0/24"
  ]

}
```

### Application Gateway Subnet

```hcl
resource "azurerm_subnet" "appgw" {

  name = "appgw-subnet"

  resource_group_name = azurerm_resource_group.rg.name

  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = [
      "10.0.2.0/24"
  ]

}
```

### Azure Firewall Subnet

```hcl
resource "azurerm_subnet" "firewall" {

  name = "AzureFirewallSubnet"

  resource_group_name = azurerm_resource_group.rg.name

  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = [
      "10.0.3.0/24"
  ]

}
```

### Private Endpoint Subnet

```hcl
resource "azurerm_subnet" "privateendpoint" {

  name = "private-endpoint-subnet"

  resource_group_name = azurerm_resource_group.rg.name

  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = [
      "10.0.4.0/24"
  ]

}
```

### AKS NSG

```hcl
resource "azurerm_network_security_group" "aks" {

  name = "aks-nsg"

  location = var.location

  resource_group_name = azurerm_resource_group.rg.name

  security_rule {

      name = "AllowHTTPS"

      priority = 100

      direction = "Inbound"

      access = "Allow"

      protocol = "Tcp"

      source_port_range = "*"

      destination_port_range = "443"

      source_address_prefix = "*"

      destination_address_prefix = "*"

  }

}
```

### Application Gateway NSG

```hcl
resource "azurerm_network_security_group" "appgw" {

  name = "appgw-nsg"

  location = var.location

  resource_group_name = azurerm_resource_group.rg.name

  security_rule {

      name = "AllowHTTP"

      priority = 100

      direction = "Inbound"

      access = "Allow"

      protocol = "Tcp"

      source_port_range = "*"

      destination_port_range = "80"

      source_address_prefix = "*"

      destination_address_prefix = "*"

  }

}
```

### NSG Association

```hcl
resource "azurerm_subnet_network_security_group_association" "aks" {

  subnet_id = azurerm_subnet.aks.id

  network_security_group_id =
  azurerm_network_security_group.aks.id

}

resource "azurerm_subnet_network_security_group_association" "appgw" {

  subnet_id = azurerm_subnet.appgw.id

  network_security_group_id =
  azurerm_network_security_group.appgw.id

}
```

### Route Table

```hcl
resource "azurerm_route_table" "rt" {

  name = "aks-route-table"

  location = var.location

  resource_group_name =
  azurerm_resource_group.rg.name

}
```

### Route

```hcl
resource "azurerm_route" "firewall" {

  name = "default-route"

  resource_group_name =
  azurerm_resource_group.rg.name

  route_table_name =
  azurerm_route_table.rt.name

  address_prefix = "0.0.0.0/0"

  next_hop_type = "VirtualAppliance"

  next_hop_in_ip_address = "10.0.3.4"

}
```

### Route Table Association

```hcl
resource "azurerm_subnet_route_table_association" "aks" {

  subnet_id = azurerm_subnet.aks.id

  route_table_id =
  azurerm_route_table.rt.id

}
```

### Public IP

```hcl
resource "azurerm_public_ip" "appgw" {

  name = "appgw-public-ip"

  location = var.location

  resource_group_name =
  azurerm_resource_group.rg.name

  allocation_method = "Static"

  sku = "Standard"

}
```

### Azure Firewall Policy

```hcl
resource "azurerm_firewall_policy" "policy" {

  name = "firewall-policy"

  location = var.location

  resource_group_name =
  azurerm_resource_group.rg.name

}
```

### Azure Firewall

```hcl
resource "azurerm_firewall" "firewall" {

  name = "azure-firewall"

  location = var.location

  resource_group_name =
  azurerm_resource_group.rg.name

  sku_name = "AZFW_VNet"

  sku_tier = "Standard"

  firewall_policy_id =
  azurerm_firewall_policy.policy.id

  ip_configuration {

      name = "configuration"

      subnet_id =
      azurerm_subnet.firewall.id

      public_ip_address_id =
      azurerm_public_ip.appgw.id

  }

}
```

---

## variables.tf

```hcl
variable "subscription_id" {}

variable "resource_group_name" {}

variable "location" {}

variable "vnet_name" {}

variable "tags" {
  type = map(string)
}
```

---

## outputs.tf

```hcl
output "vnet_id" {

  value = azurerm_virtual_network.vnet.id

}

output "aks_subnet_id" {

  value = azurerm_subnet.aks.id

}

output "appgw_subnet_id" {

  value = azurerm_subnet.appgw.id

}

output "private_endpoint_subnet_id" {

  value = azurerm_subnet.privateendpoint.id

}
```

---

## terraform.tfvars

```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

resource_group_name = "rg-dev"

location = "Central India"

vnet_name = "vnet-dev"

tags = {

  Environment = "Dev"

  Owner = "DevOps"

}
```

---

## Azure Firewall Policy (Extended)

```hcl
resource "azurerm_firewall_policy" "policy" {

  name                = "fw-policy"

  location            = var.location

  resource_group_name = azurerm_resource_group.rg.name

  sku = "Standard"

}
```

### Firewall Rule Collection Group

```hcl
resource "azurerm_firewall_policy_rule_collection_group" "default" {

  name               = "default-rule-group"

  firewall_policy_id = azurerm_firewall_policy.policy.id

  priority           = 100

  network_rule_collection {

    name     = "network-rules"

    priority = 100

    action   = "Allow"

    rule {

      name = "AllowHTTPS"

      protocols = [
        "TCP"
      ]

      source_addresses = [
        "10.0.1.0/24"
      ]

      destination_addresses = [
        "20.20.20.20"
      ]

      destination_ports = [
        "443"
      ]

    }

  }

  application_rule_collection {

    name     = "application-rules"

    priority = 200

    action   = "Allow"

    rule {

      name = "GitHub"

      source_addresses = [
        "10.0.1.0/24"
      ]

      destination_fqdns = [
        "github.com"
      ]

      protocols {

        type = "Https"

        port = 443

      }

    }

    rule {

      name = "Microsoft"

      source_addresses = [
        "10.0.1.0/24"
      ]

      destination_fqdns = [
        "microsoft.com"
      ]

      protocols {

        type = "Https"

        port = 443

      }

    }

    rule {

      name = "AzureContainerRegistry"

      source_addresses = [
        "10.0.1.0/24"
      ]

      destination_fqdns = [
        "*.azurecr.io"
      ]

      protocols {

        type = "Https"

        port = 443

      }

    }

  }

  nat_rule_collection {

    name = "nat-rules"

    priority = 300

    action = "Dnat"

    rule {

      name = "HTTPS"

      protocols = [
        "TCP"
      ]

      source_addresses = [
        "*"
      ]

      destination_address = azurerm_public_ip.firewall.ip_address

      destination_ports = [
        "443"
      ]

      translated_address = "10.0.2.10"

      translated_port = "443"

    }

  }

}
```

### Dedicated Public IP for Azure Firewall

```hcl
resource "azurerm_public_ip" "firewall" {

  name = "firewall-public-ip"

  location = var.location

  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"

  sku = "Standard"

}
```

### Azure Firewall (with Dedicated Public IP)

```hcl
resource "azurerm_firewall" "firewall" {

  name = "azure-firewall"

  location = var.location

  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "AZFW_VNet"

  sku_tier = "Standard"

  firewall_policy_id = azurerm_firewall_policy.policy.id

  ip_configuration {

    name = "configuration"

    subnet_id = azurerm_subnet.firewall.id

    public_ip_address_id = azurerm_public_ip.firewall.id

  }

}
```

---

## Real-Time Flow

```
Internet
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
Route Table (UDR)
     │
     ▼
Azure Firewall
     │
     ▼
Firewall Policy
     │
     ├────────────► Network Rules
     │
     ├────────────► Application Rules (FQDN)
     │
     └────────────► NAT Rules
     │
     ▼
Azure Services / Internet
```

---

## Interview Explanation

### Network Rule
Used when the destination is an IP address.

**Example:**
```
AKS → 20.20.20.20:443
```

### Application Rule
Used when the destination is an FQDN.

**Examples:**
- github.com
- microsoft.com
- *.azurecr.io
- api.stripe.com

The Azure Firewall resolves the FQDN and enforces the rule.

### NAT Rule
Used for inbound traffic.

**Example:**
```
Internet
  ↓
Firewall Public IP
  ↓
Private IP
  ↓
Internal Server
```

---

> **Note:** This is the production-style Azure Firewall Policy configuration recommended for discussion in interviews, as it demonstrates all three rule types (network, application, NAT) and uses a dedicated Public IP for the firewall. It fits into the broader Azure networking architecture (AKS, App Gateway, Firewall, Front Door) commonly covered in platform engineering interview prep.
