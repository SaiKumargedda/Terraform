# Terraform Azure Interview Questions (4+ Years Experience)

A comprehensive Q&A guide covering Terraform on Azure — architecture, state management, modules, environment strategy, and real production scenarios. Ideal for Azure DevOps / Terraform engineers preparing for 4–6 year experience-level interviews.

---

## Table of Contents

- [Project Architecture & Modules](#project-architecture--modules)
- [State Management](#state-management)
- [Environment Management](#environment-management)
- [CI/CD Integration](#cicd-integration)
- [Dependency & Lifecycle Management](#dependency--lifecycle-management)
- [Secrets & Security](#secrets--security)
- [Versioning & Rollback](#versioning--rollback)
- [Troubleshooting & Real Production Scenarios](#troubleshooting--real-production-scenarios)
- [Scenario-Based Questions](#scenario-based-questions)
- [Module Types](#module-types)
- [count vs for_each](#count-vs-for_each)
- [Enabling Locking & Versioning on Azure Storage Backend](#enabling-locking--versioning-on-azure-storage-backend)
- [Multi-Environment AKS Example](#multi-environment-aks-example)

---

## Project Architecture & Modules

### 1. Explain your Terraform project architecture

Our Terraform code was organized in a modular structure:

```
terraform/
│
├── modules/
│   ├── vnet
│   ├── aks
│   ├── acr
│   ├── keyvault
│   ├── appgateway
│   ├── monitoring
│
├── environments/
│   ├── dev
│   ├── qa
│   └── prod
│
├── backend.tf
├── providers.tf
├── versions.tf
├── variables.tf
└── outputs.tf
```

Each environment only passed different `tfvars`. We reused the same modules across all environments.

### 2. Why did you use modules?

Modules helped us:
- Avoid duplicate code
- Standardize infrastructure
- Simplify maintenance
- Version infrastructure
- Improve reusability

**Example:** Instead of writing AKS creation three times, we created one AKS module and reused it for Dev, QA, and Production.

### 3. Which Azure resources did you create using Terraform?

- Resource Groups
- VNets / Subnets / NSGs
- AKS
- ACR
- Azure Key Vault
- Log Analytics Workspace
- Application Insights
- Azure Monitor Alerts
- Managed Identity
- Role Assignments
- Application Gateway
- Public IP
- Azure DNS
- Private Endpoints
- Storage Account for tfstate

---

## State Management

### 4. Where was your Terraform state stored?

Terraform state was stored in an **Azure Storage Account Blob Container**.

Backend configuration required:
- Storage Account
- Container
- tfstate file

State locking was automatically handled through the Azure Blob lease mechanism.

### 5. Why remote backend?

Because multiple engineers worked together. Without a remote backend, everyone would have different state files.

Remote backend:
- Stores centralized state
- Supports locking
- Enables collaboration
- Prevents corruption

### 6. Explain state locking

If Developer A runs `terraform apply`, Terraform acquires a blob lease. Developer B cannot modify infrastructure until the lease is released — this prevents concurrent updates.

---

## Environment Management

### 7. How did you manage different environments?

We maintained:
- `dev.tfvars`
- `qa.tfvars`
- `prod.tfvars`

Pipeline passed:
```bash
terraform apply -var-file=prod.tfvars
```

Same code. Different variables. Different environments.

### 8. Did you use Terraform Workspaces?

No — environment isolation becomes difficult with workspaces. Instead, we maintained separate folders:

```
environments/dev
environments/qa
environments/prod
```

This is Microsoft's recommended enterprise approach.

---

## CI/CD Integration

### 9. How did Terraform integrate with Azure DevOps?

Pipeline stages:

```
Terraform Init
   ↓
Terraform Validate
   ↓
Terraform fmt
   ↓
Terraform Plan
   ↓
Manual Approval
   ↓
Terraform Apply
```

Authentication happened through an Azure Service Connection using a Service Principal.

### 10. How did Terraform authenticate to Azure?

```
Azure DevOps Service Connection
   ↓
Azure Service Principal
   ↓
Contributor permissions on subscription/resource group
```

Terraform automatically used ARM credentials.

### 11. What improvements did you implement?

- ✔ Modular Terraform
- ✔ Remote backend
- ✔ Version pinning
- ✔ Pipeline approvals
- ✔ Automatic formatting (`terraform fmt`)
- ✔ Validation (`terraform validate`)
- ✔ Plan artifact publishing
- ✔ Code review before Apply
- ✔ Separate tfvars
- ✔ Resource tagging
- ✔ Naming conventions
- ✔ Secrets moved to Azure Key Vault

---

## Dependency & Lifecycle Management

### 20. Explain `depends_on`

Sometimes Terraform cannot infer dependency automatically. Example:

```
AKS
 ↓
needs Role Assignment first
```

`depends_on` ensures correct creation order.

### 21. What Azure-specific dependencies did you manage?

```
AKS
 ↓
Managed Identity
 ↓
Role Assignment
 ↓
Subnet
 ↓
ACR Pull Role
 ↓
Node Pool
```

### 18. How did you protect production resources?

```hcl
lifecycle {
  prevent_destroy = true
}
```

Critical resources (Storage, Key Vault, Database) couldn't be accidentally destroyed.

### 19. Why `ignore_changes`?

```hcl
lifecycle {
  ignore_changes = [
    tags
  ]
}
```

Azure automatically updates tags sometimes — Terraform shouldn't recreate resources unnecessarily.

---

## Secrets & Security

### 22. How do you manage secrets?

Never stored secrets inside tfvars. Secrets came from:
- Azure Key Vault
- Azure DevOps Variable Groups

### 33. Have you used Managed Identity?

Yes — AKS, Application Gateway, and Key Vault used Managed Identity. Terraform assigned the required RBAC roles.

---

## Versioning & Rollback

### 23. How did you handle Terraform versions?

Used `required_version` and `required_providers` to avoid version mismatch.

### 24. Explain provider version pinning

```hcl
terraform {
  required_providers {
    azurerm = {
      version = "~>4.0"
    }
  }
}
```

This avoids unexpected provider upgrades.

### 26. How do you rollback Terraform?

Terraform has no built-in rollback. Rollback means:

```
Restore previous code
   ↓
Run terraform apply
   ↓
Infrastructure becomes previous version
```

### 30. What is `terraform taint`?

```bash
terraform taint resource
```

Marks a resource for recreation — the next apply recreates only that resource.

---

## Troubleshooting & Real Production Scenarios

### 16. How do you detect infrastructure drift?

Using `terraform plan` — if someone modifies the Azure Portal manually, Terraform detects the differences.

### 17. What happens if someone deletes AKS manually?

The next `terraform plan` shows that AKS will be created — Terraform tries to bring infrastructure back.

### 35. Real Production Issue

**Q: Terraform Apply suddenly failed after creating half the resources. What did you do?**

1. Checked the Azure Portal to verify what resources were already created.
2. Ran `terraform state list` to compare against actual state.
3. If state was missing → used `terraform import`.
4. If there was a partial state mismatch → used `terraform refresh`.
5. Reran `terraform plan` — only remaining resources were created.
6. Never deleted state manually.

### 13. Terraform state corruption

**Cause:** Someone interrupted an apply.

**Solution:**
- Recovered state using `terraform refresh`
- Imported missing resources using `terraform import`
- Enabled state locking

### 36. Biggest improvement introduced

> We moved from manual Azure Portal deployments to Infrastructure as Code using Terraform. We modularized infrastructure, centralized state in Azure Blob Storage with locking, integrated Terraform into Azure DevOps pipelines with validation, formatting, plan approval, and secure authentication using Service Principals. This reduced manual errors, improved deployment consistency, enabled code reviews, and made infrastructure changes repeatable across Dev, QA, and Production environments.

---

## Scenario-Based Questions

1. A developer accidentally modified an NSG rule in the Azure Portal. How would Terraform detect and fix it?
2. Your `terraform apply` fails because a resource with the same name already exists. How would you resolve it?
3. How would you migrate an existing manually created Azure environment to Terraform without downtime?
4. How would you deploy the same AKS architecture to three subscriptions using one codebase?
5. A production `terraform apply` fails midway. What are your recovery steps?
6. How would you safely rename a Terraform resource without recreating it? (using `moved` blocks or `terraform state mv`)
7. How do you ensure Terraform changes are reviewed before deployment?
8. How do you prevent accidental deletion of critical Azure resources?
9. How would you handle provider version upgrades in a production environment?
10. When would you use a `data` block instead of creating a resource?

---

## Module Types

Terraform officially has three types of modules:

| Module Type | Description | Example |
|---|---|---|
| Root Module | Main module from where Terraform execution starts | `terraform apply` in root folder |
| Child Module | Reusable module called by root module | AKS module, VNet module |
| Registry Module | Modules downloaded from Terraform Registry or Git | Azure AVM modules |

### Root Module

```
terraform/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
```

```hcl
module "vnet" {
  source = "./modules/vnet"
  resource_group_name = var.rg
}
```

### Child Module

```
modules/
   vnet/
      main.tf
      variables.tf
      outputs.tf
```

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = var.name
  address_space       = var.address_space
  resource_group_name = var.rg
}
```

Called from root:

```hcl
module "network" {
  source = "./modules/vnet"
}
```

### Registry Module

```hcl
module "aks" {
  source  = "Azure/aks/azurerm"
  version = "9.0.0"
}
```

Terraform downloads this automatically from the Terraform Registry.

**Interview Answer:** We mainly used Child Modules developed internally for networking, AKS, Key Vault, ACR, Monitoring, and Application Gateway. We also evaluated Azure Verified Modules (AVM) from the Terraform Registry for standard resources.

---

## count vs for_each

### `count`

```hcl
resource "azurerm_resource_group" "rg" {
  count    = 3
  name     = "rg-${count.index}"
  location = "Central India"
}
```

Output: `rg-0`, `rg-1`, `rg-2`

Access: `azurerm_resource_group.rg[0]`

Use when resources are almost identical (e.g., 3 Storage Accounts, 3 Public IPs, 3 VMs).

### `for_each` (set)

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = toset(["dev", "qa", "prod"])
  name     = "rg-${each.key}"
  location = "Central India"
}
```

Output: `rg-dev`, `rg-qa`, `rg-prod`

Access: `azurerm_resource_group.rg["dev"]`

### `for_each` (map)

```hcl
locals {
  resource_groups = {
    dev  = "Central India"
    qa   = "South India"
    prod = "West India"
  }
}

resource "azurerm_resource_group" "rg" {
  for_each = local.resource_groups
  name     = "rg-${each.key}"
  location = each.value
}
```

Output: `rg-dev` → Central India, `rg-qa` → South India, `rg-prod` → West India

### Why `toset()`?

`for_each` works only with maps or sets. If you have a list, convert it to a set to get unique values:

```hcl
locals {
  envs = ["dev", "qa", "prod", "dev"]
}

resource "azurerm_resource_group" "rg" {
  for_each = toset(local.envs)
  name     = "rg-${each.key}"
  location = "Central India"
}
```

Terraform creates only: `rg-dev`, `rg-qa`, `rg-prod` (duplicate removed).

### Complex Map Example

```hcl
locals {
  storage_accounts = {
    dev = {
      location = "Central India"
      tier     = "Standard"
    }
    qa = {
      location = "South India"
      tier     = "Premium"
    }
  }
}

resource "azurerm_storage_account" "storage" {
  for_each                  = local.storage_accounts
  name                       = "st${each.key}"
  location                   = each.value.location
  account_tier                = each.value.tier
  resource_group_name         = "demo"
  account_replication_type    = "LRS"
}
```

### Comparison Table

| Feature | `count` | `for_each` |
|---|---|---|
| Uses | Numeric index | Keys (map/set) |
| Access | `count.index` | `each.key`, `each.value` |
| Best for | Identical resources | Resources with unique names/properties |
| If one item is removed | Indexes shift, may recreate resources | Only the removed key is affected |
| Enterprise preference | Less preferred | Preferred for most production use cases |

**Interview Answer:** In enterprise projects, we generally prefer `for_each` over `count` because resources are identified by stable keys rather than indexes. This avoids unnecessary resource recreation when items are added or removed from the collection. We typically use `count` only when creating multiple identical resources where index-based naming is acceptable.

---

## Enabling Locking & Versioning on Azure Storage Backend

**Q: How do you enable locking and versioning for the Terraform state stored in an Azure Storage Account? How do you use them?**

**Short Answer:** We store the Terraform state in an Azure Storage Account using the AzureRM backend. We enable blob versioning and soft delete on the storage account to protect the state file from accidental deletion or corruption. Terraform automatically uses Azure Blob leases for state locking during `terraform apply`, preventing concurrent updates. We also restrict access using RBAC and disable public access.

### Backend Configuration

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

### How Locking Works

You do **not** manually enable state locking. When using the AzureRM backend, Terraform automatically acquires a Blob Lease on the state file:

```
Developer A runs terraform apply
   ↓
Acquire Blob Lease
   ↓
Lock State File
   ↓
Update Infrastructure
   ↓
Update State
   ↓
Release Lease
```

If Developer B runs `terraform apply` at the same time, Terraform returns an error acquiring the state lock, and Developer B must wait.

### Enabling Blob Versioning (via Terraform)

```hcl
resource "azurerm_storage_account" "tfstate" {
  name                     = "stterraformstate"
  resource_group_name      = "rg-tfstate"
  location                 = "Central India"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}
```

Or via Azure Portal: **Storage Account → Data Protection →** enable Blob Versioning, Soft Delete, Change Feed (optional), Point-in-Time Restore (optional).

### Why Versioning Matters

If the current state blob becomes corrupted, you can restore a previous version. Without versioning, state is lost and Terraform cannot track infrastructure correctly. Restoring is done via **Storage Account → Container → terraform.tfstate → Versions → Restore** — no Terraform commands needed.

### Additional Security Best Practices

- Disable public blob access
- Use private endpoints (if required)
- Azure RBAC (`Storage Blob Data Contributor` for pipeline identity)
- Encryption at rest (enabled by Azure)
- Soft delete
- Versioning
- Least privilege access

### Real Production Scenario

**Q: What if someone accidentally deletes the state file?**

If soft delete is enabled:
1. Recover the deleted blob from Azure Storage.
2. Restore the latest version.
3. Run `terraform plan` to verify the recovered state matches the infrastructure.

Without soft delete or versioning, recovery is much harder and may require rebuilding the state using `terraform import`.

> **Note:** We don't lock the Storage Account itself — Terraform locks only the specific `terraform.tfstate` blob using an Azure Blob Lease. Other blobs remain accessible.

**Best-Practice Interview Answer:** "We use an Azure Storage Account as the Terraform remote backend. Blob versioning and soft delete are enabled to protect the state file and allow recovery if it's accidentally deleted or corrupted. During `terraform apply`, Terraform automatically acquires an Azure Blob Lease on the state file, which prevents concurrent updates by other users or pipelines. Once the operation completes, the lease is released. Access to the storage account is controlled using Azure RBAC, and public access is disabled to secure the state."

---

## Multi-Environment AKS Example

**Enterprise approach:** One reusable AKS module + separate environment folders + separate tfvars files. The module stays the same; only the input variables change.

### Project Structure

```
terraform/
│
├── modules/
│   └── aks/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   └── terraform.tfvars
│   │
│   ├── qa/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   │
│   └── prod/
│       ├── main.tf
│       └── terraform.tfvars
```

### AKS Module — `modules/aks/main.tf`

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group

  dns_prefix = var.cluster_name

  default_node_pool {
    name       = "system"
    vm_size    = var.vm_size
    node_count = var.node_count
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
```

### Module Variables — `modules/aks/variables.tf`

```hcl
variable "cluster_name" {}
variable "resource_group" {}
variable "location" {}
variable "node_count" {}
variable "vm_size" {}

variable "tags" {
  type = map(string)
}
```

### Dev Environment — `environments/dev/main.tf`

```hcl
module "aks" {
  source = "../../modules/aks"

  cluster_name   = var.cluster_name
  resource_group = var.resource_group
  location       = var.location

  node_count = var.node_count
  vm_size    = var.vm_size

  tags = var.tags
}
```

### tfvars per Environment

**Dev:**
```hcl
cluster_name   = "aks-dev"
resource_group = "rg-dev"
location       = "Central India"
node_count     = 2
vm_size        = "Standard_DS2_v2"

tags = {
  Environment = "Dev"
  Owner       = "Platform"
}
```

**QA:**
```hcl
cluster_name   = "aks-qa"
resource_group = "rg-qa"
location       = "Central India"
node_count     = 3
vm_size        = "Standard_DS3_v2"

tags = {
  Environment = "QA"
}
```

**Prod:**
```hcl
cluster_name   = "aks-prod"
resource_group = "rg-prod"
location       = "Central India"
node_count     = 6
vm_size        = "Standard_D8s_v5"

tags = {
  Environment = "Production"
  Critical    = "Yes"
}
```

### Pipeline Commands

```bash
# Dev
terraform apply -var-file=environments/dev/terraform.tfvars

# QA
terraform apply -var-file=environments/qa/terraform.tfvars

# Production
terraform apply -var-file=environments/prod/terraform.tfvars
```

The code remains the same — only the input values differ.

### What Changes Between Environments

| Configuration | Dev | QA | Prod |
|---|---|---|---|
| Cluster Name | aks-dev | aks-qa | aks-prod |
| Node Count | 2 | 3 | 6 |
| VM Size | DS2_v2 | DS3_v2 | D8s_v5 |
| Auto Scaling | Disabled/Small | Enabled | Enabled |
| Min Nodes | 1 | 2 | 3 |
| Max Nodes | 3 | 5 | 10 |
| Log Analytics | Shared | Dedicated | Dedicated |
| SKU | Free | Standard | Premium |
| Tags | Dev | QA | Production |

### Enterprise Improvement — Object Variables

Instead of passing many individual variables, use an object variable:

```hcl
variable "aks_config" {
  type = object({
    cluster_name = string
    node_count   = number
    vm_size      = string
    location     = string
  })
}
```

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name     = var.aks_config.cluster_name
  location = var.aks_config.location
}
```

Each environment passes a different object in its `terraform.tfvars`, making the configuration cleaner and easier to maintain.

**Recommended Interview Answer:** "In our project, we maintained a single reusable AKS module and separate environment folders for Dev, QA, and Production. The module contained the common AKS configuration, while each environment had its own `terraform.tfvars` file with values such as cluster name, node count, VM size, autoscaling limits, tags, and resource group. Our Azure DevOps pipeline selected the appropriate tfvars file based on the target environment. This allowed us to reuse the same code while provisioning different-sized AKS clusters with environment-specific configurations, reducing duplication and ensuring consistency across environments."

---

## License

Free to use for interview preparation and learning purposes.
