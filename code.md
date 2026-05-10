# Azure Terraform + AKS + Networking + Monitoring + CI/CD Complete Interview Guide

---

# 1. Terraform Basics

## Provider Configuration

```hcl
provider "azurerm" {
  features {}
}
```

---

# Resource Group

```hcl
resource "azurerm_resource_group" "rg" {

  name     = "rg_dev"
  location = "Central India"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    env     = "dev"
    project = "aks-demo"
  }
}
```

## Important Notes

* `prevent_destroy = true` avoids accidental deletion.
* Resource Groups logically group Azure resources.
* Tags help in governance and cost tracking.

---

# Using Variables Instead of Hardcoding

## variables.tf

```hcl
variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}
```

## main.tf

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}
```

---

# Terraform Backend Configuration

## Purpose

Used for remote state storage.

Benefits:

* Shared collaboration
* State locking
* Centralized state
* Safer CI/CD

## Backend Example

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateprod"
    container_name       = "tfstate"
    key                  = "aks-prod.tfstate"
  }
}
```

---

# Terraform Import

```bash
terraform import azurerm_resource_group.rg /subscriptions/<id>/resourceGroups/rg-name
```

## Purpose

Used to bring existing Azure resources into Terraform state.

---

# 2. Azure Networking

# Virtual Network

```hcl
resource "azurerm_virtual_network" "vnet" {

  name                = "vnet_dev"
  location            = "Central India"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}
```

---

# Subnets

```hcl
resource "azurerm_subnet" "subnet_app" {

  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet_db" {

  name                 = "subnet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
```

---

# VNet Peering

```hcl
resource "azurerm_virtual_network_peering" "peer" {

  name                      = "vnet-peer"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = "<remote-vnet-id>"
}
```

## Purpose

Allows communication between VNets privately over Azure backbone.

---

# NSG (Network Security Group)

```hcl
resource "azurerm_network_security_group" "nsg" {

  name                = "nsg-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
```

---

# NSG Rule

```hcl
resource "azurerm_network_security_rule" "allow_ssh" {

  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"

  source_port_range          = "*"
  destination_port_range     = "22"

  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}
```

---

# Associate NSG with Subnet

```hcl
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {

  subnet_id                 = azurerm_subnet.subnet_app.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```

---

# ASG (Application Security Group)

## Purpose

ASGs logically group resources.

Instead of IP-based rules:

```text
10.0.2.0/24 → 10.0.3.0/24
```

We use:

```text
asg-app → asg-db
```

---

# ASG Example

```hcl
resource "azurerm_application_security_group" "asg" {

  name                = "asg-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
```

---

# ASG Based NSG Rule

```hcl
resource "azurerm_network_security_rule" "allow_http_asg" {

  name                        = "allow-http"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"

  source_port_range      = "*"
  destination_port_range = "80"

  source_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name

  destination_application_security_group_ids = [
    azurerm_application_security_group.asg.id
  ]
}
```

---

# Interview Explanation

“We use ASGs to logically group resources like AKS and databases, and NSGs reference ASGs instead of IP addresses, making rules scalable and easier to manage.”

---

# 3. Linux Virtual Machine

# Network Interface

```hcl
resource "azurerm_network_interface" "nic" {

  name                = "nic-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_app.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

---

# Linux VM

```hcl
resource "azurerm_linux_virtual_machine" "vm" {

  name                = "vm-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"

  admin_username = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
```

---

# Public IP

```hcl
resource "azurerm_public_ip" "pip" {

  name                = "vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
}
```

---

# 4. Azure Container Registry (ACR)

```hcl
resource "azurerm_container_registry" "acr" {

  name                = "acr123demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku           = "Standard"
  admin_enabled = false

  tags = {
    environment = "dev"
  }
}
```

---

# 5. Azure Kubernetes Service (AKS)

```hcl
resource "azurerm_kubernetes_cluster" "aks" {

  name                = "aks-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aksdemo"

  default_node_pool {
    name                 = "systempool"
    vm_size              = "Standard_DS2_v2"
    enable_auto_scaling  = true
    min_count            = 1
    max_count            = 5
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  role_based_access_control_enabled = true

  tags = {
    environment = "dev"
  }
}
```

---

# ACR Pull Access for AKS

```hcl
resource "azurerm_role_assignment" "aks_acr" {

  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}
```

## Important Understanding

* kubelet/container runtime pulls images
* AKS kubelet identity needs AcrPull role

---

# User Node Pool

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "userpool" {

  name                  = "userpool1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id

  vm_size   = "Standard_DS2_v2"
  node_count = 2

  mode = "User"

  orchestrator_version = azurerm_kubernetes_cluster.aks.kubernetes_version
}
```

---

# Interview Understanding

## System Node Pools

Used for:

* CoreDNS
* kube-proxy
* CNI
* metrics-server

## User Node Pools

Used for:

* application workloads
* APIs
* frontend apps
* batch jobs

---

# 6. Azure Load Balancer

## Layer 4 Load Balancer

Works on:

* TCP
* UDP

---

# Public IP for LB

```hcl
resource "azurerm_public_ip" "pip" {

  name                = "lb-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}
```

---

# Load Balancer

```hcl
resource "azurerm_lb" "lb" {

  name                = "lb-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}
```

---

# Interview Explanation

“It is a Layer 4 load balancer that distributes traffic based on IP and port across backend resources.”

---

# 7. Azure Application Gateway

## Layer 7 Load Balancer

Supports:

* HTTP/HTTPS
* SSL termination
* WAF
* path-based routing
* cookie affinity

---

# Application Gateway

```hcl
resource "azurerm_application_gateway" "appgw" {

  name                = "appgw-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
}
```

---

# Interview Explanation

“I’m creating an Application Gateway with WAF_v2 SKU for Layer 7 routing. It supports SSL termination, WAF protection, and intelligent HTTP/HTTPS routing.”

---

# 8. NAT Gateway

## Purpose

Provides controlled outbound internet access.

---

```hcl
resource "azurerm_nat_gateway" "nat" {

  name                = "nat-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "Standard"
}
```

---

# Interview Explanation

“NAT Gateway provides outbound internet access with a static public IP while keeping workloads private.”

---

# 9. Route Tables (UDR)

```hcl
resource "azurerm_route_table" "rt" {

  name                = "rt-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
```

---

# Default Route

```hcl
resource "azurerm_route" "route_internet" {

  name                = "route-to-internet"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name    = azurerm_route_table.rt.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}
```

---

# 10. Azure Firewall

## Purpose

Centralized enterprise security layer.

Supports:

* traffic inspection
* DNAT/SNAT
* URL filtering
* threat intelligence

---

```hcl
resource "azurerm_firewall" "fw" {

  name                = "az-fw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "AZFW_VNet"
  sku_tier = "Standard"
}
```

---

# Interview Explanation

“Azure Firewall acts as a centralized security layer to inspect and control inbound and outbound traffic.”

---

# 11. Private Endpoint

## Purpose

Access Azure PaaS services privately.

No public internet exposure.

---

```hcl
resource "azurerm_private_endpoint" "pe" {

  name                = "pe-storage"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_app.id

  private_service_connection {
    name                           = "pe-connection"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}
```

---

# Interview Explanation

“Private Endpoints provide private connectivity to Azure services using private IPs within the VNet.”

---

# 12. Azure Key Vault

```hcl
resource "azurerm_key_vault" "kv" {

  name                        = "kv-demo-12345"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  sku_name = "standard"

  soft_delete_enabled      = true
  purge_protection_enabled = true
}
```

---

# Store Secret

```hcl
resource "azurerm_key_vault_secret" "secret" {

  name         = "db-password"
  value        = "Password123!"
  key_vault_id = azurerm_key_vault.kv.id
}
```

---

# Give AKS Access

```hcl
resource "azurerm_role_assignment" "kv_access" {

  principal_id         = "<managed-identity-id>"
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.kv.id
}
```

---

# 13. Azure DNS

# DNS Zone

```hcl
resource "azurerm_dns_zone" "dns" {

  name                = "mydomain.com"
  resource_group_name = azurerm_resource_group.rg.name
}
```

---

# A Record

```hcl
resource "azurerm_dns_a_record" "app" {

  name                = "app"
  zone_name           = azurerm_dns_zone.dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  records = [
    azurerm_public_ip.appgw_pip.ip_address
  ]
}
```

---

# CNAME Record

```hcl
resource "azurerm_dns_cname_record" "cname" {

  name                = "www"
  zone_name           = azurerm_dns_zone.dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  record = "app.mydomain.com"
}
```

---

# Interview Explanation

“A CNAME maps one domain name to another domain name.”

---

# 14. Azure Front Door

## Global Load Balancer

Supports:

* global routing
* health probes
* WAF
* SSL offloading
* CDN acceleration

---

# End-to-End Flow

```text
User → DNS
      → Azure Front Door
      → Application Gateway
      → AKS
      → Pod
```

---

# 15. Azure Monitoring

# Log Analytics Workspace

```hcl
resource "azurerm_log_analytics_workspace" "law" {

  name                = "law-prod"
  location            = "Central India"
  resource_group_name = "rg-monitoring"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
```

---

# Application Insights

```hcl
resource "azurerm_application_insights" "appi" {

  name                = "appi-prod"
  location            = "Central India"
  resource_group_name = "rg-monitoring"
  application_type    = "web"

  workspace_id = azurerm_log_analytics_workspace.law.id
}
```

---

# Container Insights Integration

```hcl
oms_agent {
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}
```

---

# Action Group

```hcl
resource "azurerm_monitor_action_group" "ag" {

  name                = "ag-prod"
  resource_group_name = "rg-monitoring"
  short_name          = "alertgrp"

  email_receiver {
    name          = "admin-email"
    email_address = "admin@example.com"
  }
}
```

---

# CPU Alert

```hcl
resource "azurerm_monitor_metric_alert" "cpu_alert" {

  name                = "cpu-high-alert"
  resource_group_name = "rg-monitoring"
  scopes              = [azurerm_kubernetes_cluster.aks.id]

  description = "CPU usage high"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}
```

---

# Common KQL Queries

## Failed Pods

```kql
KubePodInventory
| where PodStatus == "Failed"
```

---

## High CPU

```kql
Perf
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer
```

---

# 16. Terraform Modules

## Purpose

Reusable Terraform code.

---

# Folder Structure

```text
modules/
 ├── vnet/
 ├── aks/
 ├── storage/
```

---

# Module Example

```hcl
module "vnet" {

  source        = "./modules/vnet"
  name          = "vnet-dev"
  address_space = ["10.0.0.0/16"]
  location      = "Central India"
  rg_name       = "rg-dev"
}
```

---

# 17. count vs for_each

# count

```hcl
resource "azurerm_resource_group" "rg" {

  count = 2
  name  = "rg-${count.index}"
}
```

---

# for_each

```hcl
resource "azurerm_resource_group" "rg" {

  for_each = toset(["dev", "prod"])

  name = "rg-${each.key}"
}
```

---

# Interview Understanding

We prefer:

```text
for_each
```

because:

* stable resource mapping
* avoids index shifting issues

---

# 18. Multi-Environment Terraform Structure

```text
terraform/
│
├── modules/
│   └── aks/
│
├── backend/
│   └── bootstrap.tf
│
├── envs/
│   ├── dev/
│   ├── prod/
```

---

# Key Understanding

| Component  | Purpose            |
| ---------- | ------------------ |
| tfvars     | environment values |
| backend.tf | state isolation    |
| modules    | reusable code      |

---

# 19. 3-Tier Architecture

| Tier     | Purpose        | Example     |
| -------- | -------------- | ----------- |
| Web Tier | Entry point    | App Gateway |
| App Tier | Business logic | AKS         |
| DB Tier  | Data storage   | Azure SQL   |

---

# End-to-End Flow

```text
User
  ↓
Application Gateway
  ↓
AKS Ingress
  ↓
Service
  ↓
Pod
  ↓
Database
```

---

# 20. AKS to Database Secure Flow

# Private Endpoint

```text
AKS → Private Endpoint → Azure SQL
```

No public internet involved.

---

# JDBC Connection Example

```text
jdbc:sqlserver://mydb.privatelink.database.windows.net:1433;
database=mydb;
user=admin;
password=*****
```

---

# Secret Management

## Recommended

Use:

* Key Vault
* Managed Identity
* Workload Identity
* CSI Driver

---

# End-to-End Secure Flow

```text
User
 ↓
Application Gateway
 ↓
AKS Ingress
 ↓
Pod
 ↓
Fetch Secret from Key Vault
 ↓
Build JDBC URL
 ↓
Connect to Azure SQL via Private Endpoint
```

---

# 21. Azure DevOps CI/CD with WIF

# Flow

```text
Developer
   ↓
Azure Repo
   ↓
Pipeline Triggered
   ↓
Service Connection (WIF)
   ↓
OIDC Token
   ↓
Azure AD Federation
   ↓
Access Token
   ↓
Terraform → Azure API
```

---

# Required RBAC Roles

| Purpose           | Role                          |
| ----------------- | ----------------------------- |
| Infra Creation    | Contributor                   |
| Terraform Backend | Storage Blob Data Contributor |
| Key Vault         | Key Vault Secrets User        |

---

# Example Role Assignment

```hcl
resource "azurerm_role_assignment" "storage" {

  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = "<spn-object-id>"
}
```

---

# Azure DevOps YAML Pipeline

```yaml
trigger:
- main

variables:
  TF_VERSION: '1.5.0'
  SERVICE_CONNECTION: 'sc-wif-terraform'
```

---

# Interview Explanation

“In a WIF-based setup, Azure DevOps uses a service connection linked to a service principal. Azure AD validates the OIDC token and issues temporary access tokens without storing secrets.”

---

# Final Interview Summary

“This architecture uses Terraform modules, remote state storage, Azure networking, AKS, private endpoints, Key Vault, Application Gateway, Azure Front Door, Container Insights, and Azure DevOps CI/CD with Workload Identity Federation to build secure, scalable, and production-grade Azure infrastructure.”
