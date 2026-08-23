# Terraform Azure Interview Questions — 4+ Years Experience

A comprehensive Q&A reference covering project architecture, modules, state management, environment strategy, count/for_each, storage account locking/versioning, and multi-environment AKS deployment.

---

## Table of Contents

**Part A — Project & Process**
1. [Terraform Project Architecture](#1-explain-your-terraform-project-architecture)
2. [Why Use Modules?](#2-why-did-you-use-modules)
3. [Azure Resources Created via Terraform](#3-which-azure-resources-did-you-create-using-terraform)
4. [Where Was State Stored?](#4-where-was-your-terraform-state-stored)
5. [Why Remote Backend?](#5-why-remote-backend)
6. [State Locking](#6-explain-state-locking)
7. [Managing Environments](#7-how-did-you-manage-different-environments)
8. [Terraform Workspaces](#8-did-you-use-terraform-workspaces)
9. [Azure DevOps Integration](#9-how-did-terraform-integrate-with-azure-devops)
10. [Terraform Authentication to Azure](#10-how-did-terraform-authenticate-to-azure)
11. [Improvements Implemented](#11-what-improvements-did-you-implement)
12. [Biggest Challenge](#12-biggest-terraform-challenge)
13. [Another Challenge — State Corruption](#13-another-challenge)
14. [Importing Existing Resources](#14-have-you-imported-existing-azure-resources)
15. [Refresh vs Import](#15-difference-between-refresh-and-import)
16. [Detecting Drift](#16-how-do-you-detect-infrastructure-drift)
17. [Manual AKS Deletion](#17-what-happens-if-someone-deletes-aks-manually)
18. [Protecting Production Resources](#18-how-did-you-protect-production-resources)
19. [ignore_changes](#19-why-ignore_changes)
20. [depends_on](#20-explain-depends_on)
21. [Azure-Specific Dependencies](#21-what-azure-specific-dependencies-did-you-manage)
22. [Managing Secrets](#22-how-do-you-manage-secrets)
23. [Terraform Version Management](#23-how-did-you-handle-terraform-versions)
24. [Provider Version Pinning](#24-explain-provider-version-pinning)
25. [Provider Version Change Impact](#25-what-happens-if-provider-version-changes)
26. [Rollback Strategy](#26-how-do-you-rollback-terraform)
27. [Reviewing Changes](#27-how-do-you-review-terraform-changes)
28. [Data Blocks](#28-have-you-used-data-blocks)
29. [Resource vs Data](#29-what-is-the-difference-between-resource-and-data)
30. [Terraform Taint](#30-what-is-terraform-taint)
31. [Improving Execution Speed](#31-how-did-you-improve-terraform-execution-speed)
32. [Multiple Subscriptions](#32-how-do-you-handle-multiple-subscriptions)
33. [Managed Identity](#33-have-you-used-managed-identity)
34. [Full Terraform Lifecycle](#34-explain-terraform-lifecycle-in-your-project)
35. [Production Issue — Partial Apply Failure](#35-real-production-issue-interviewers-love)
36. [Biggest Improvement — Narrative Answer](#36-real-challenge)
37. [Scenario-Based Questions (Practice List)](#37-scenario-based-questions)

**Part B — Deep Dive Topics**
38. [Types of Terraform Modules](#38-what-are-different-types-of-terraform-modules)
39. [count vs for_each — Full Breakdown](#39-count-vs-for_each--full-breakdown)
40. [Enabling Locking & Versioning on Storage Account](#40-how-do-you-enable-locking-and-versioning-in-storage-account-and-how-you-use-it)
41. [Multi-Environment AKS with One Codebase](#41-how-do-you-create-different-resources-in-different-environments-with-different-configurations-using-terraform--aks-example)

---

## Part A — Project & Process

### 1. Explain your Terraform project architecture.

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

---

### 2. Why did you use modules?

Modules helped us:

- Avoid duplicate code
- Standardize infrastructure
- Simplify maintenance
- Version infrastructure
- Improve reusability

**Example:** Instead of writing AKS creation three times, we created one AKS module and reused it for Dev, QA and Production.

---

### 3. Which Azure resources did you create using Terraform?

We provisioned:

- Resource Groups
- VNets / Subnets / NSGs
- AKS
- ACR
- Azure Key Vault
- Log Analytics Workspace
- Application Insights
- Azure Monitor Alerts
- Managed Identity / Role Assignments
- Application Gateway
- Public IP
- Azure DNS
- Private Endpoints
- Storage Account for tfstate

---

### 4. Where was your Terraform State stored?

Terraform state was stored in an **Azure Storage Account Blob Container**.

**Backend configuration:**
- Storage Account
- Container
- tfstate file

State locking was automatically handled through the **Azure Blob lease mechanism**.

---

### 5. Why remote backend?

Because multiple engineers worked together. Without a remote backend, everyone would have different state files.

Remote backend:

- Stores centralized state
- Supports locking
- Enables collaboration
- Prevents corruption

---

### 6. Explain state locking.

Suppose Developer A is running `terraform apply`. Terraform acquires a blob lease. Developer B cannot modify infrastructure until the lease is released. This prevents concurrent updates.

---

### 7. How did you manage different environments?

We maintained:

- `dev.tfvars`
- `qa.tfvars`
- `prod.tfvars`

Pipeline passed:

```bash
terraform apply -var-file=prod.tfvars
```

Same code, different variables, different environments.

---

### 8. Did you use Terraform Workspaces?

**No.** We avoided workspaces because environment isolation becomes difficult.

Instead, we maintained separate folders:

```
environments/dev
environments/qa
environments/prod
```

which is Microsoft's recommended enterprise approach.

---

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

Authentication happened through an **Azure Service Connection** using a Service Principal.

---

### 10. How did Terraform authenticate to Azure?

```
Azure DevOps Service Connection
        ↓
Azure Service Principal
        ↓
Contributor permissions on subscription/resource group
```

Terraform automatically used ARM credentials.

---

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

### 12. Biggest Terraform challenge?

Initially, developers were applying infrastructure from laptops. Problems:

- Different provider versions
- Different state files
- No approvals
- Manual mistakes

**We improved it by** running Terraform only through the Azure DevOps pipeline.

---

### 13. Another challenge?

**Terraform state corruption.**

Reason: someone interrupted an apply.

Solution:
- Recovered state
- Used `terraform refresh`
- Imported missing resources with `terraform import`
- Enabled state locking

---

### 14. Have you imported existing Azure resources?

**Yes.** Existing production resources were imported.

Example:

```bash
terraform import azurerm_resource_group.demo \
  /subscriptions/xxx/resourceGroups/demo
```

After import, Terraform started managing those resources.

---

### 15. Difference between Refresh and Import?

| Command | Purpose |
|---|---|
| **Refresh** | Updates Terraform state to reflect real infrastructure |
| **Import** | Adds an existing resource into Terraform state |

---

### 16. How do you detect infrastructure drift?

Using `terraform plan`. If someone modifies the Azure Portal manually, Terraform detects the differences.

---

### 17. What happens if someone deletes AKS manually?

The next `terraform plan` shows that AKS will be created. Terraform tries to bring infrastructure back to the desired state.

---

### 18. How did you protect production resources?

Used the `prevent_destroy` lifecycle rule:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Critical resources — Storage, Key Vault, Database — couldn't be accidentally destroyed.

---

### 19. Why ignore_changes?

```hcl
lifecycle {
  ignore_changes = [tags]
}
```

Azure automatically updates tags sometimes. Terraform shouldn't recreate a resource unnecessarily because of that.

---

### 20. Explain depends_on.

Sometimes Terraform cannot infer a dependency automatically.

**Example:** AKS needs a Role Assignment first. `depends_on` ensures the correct creation order.

---

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

Terraform's dependency chain ensured proper provisioning order.

---

### 22. How do you manage secrets?

Never stored secrets inside tfvars. Secrets came from:

- Azure Key Vault, or
- Azure DevOps Variable Groups

---

### 23. How did you handle Terraform versions?

Used `required_version` and `required_providers` to avoid version mismatch.

---

### 24. Explain provider version pinning.

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

---

### 25. What happens if provider version changes?

A new provider may:

- Change API behavior
- Deprecate resources
- Change attributes

So we tested provider upgrades in lower environments first.

---

### 26. How do you rollback Terraform?

Terraform has **no rollback**. Rollback means:

```
Restore previous code
        ↓
Run terraform apply
        ↓
Infrastructure becomes previous version
```

---

### 27. How do you review Terraform changes?

```
Terraform Plan
      ↓
Publish Plan Artifact
      ↓
Reviewer checks
      ↓
Approval
      ↓
Terraform Apply
```

---

### 28. Have you used data blocks?

Yes — instead of creating a VNet:

```hcl
data "azurerm_virtual_network" "existing" {
  name                = "vnet-shared"
  resource_group_name = "rg-network"
}
```

Useful when the networking team owns the VNet.

---

### 29. What is the difference between resource and data?

| Block | Purpose |
|---|---|
| **resource** | Creates infrastructure |
| **data** | Reads existing infrastructure |

---

### 30. What is Terraform taint?

```bash
terraform taint <resource>
```

Marks a resource for recreation. The next apply recreates only that resource.

---

### 31. How did you improve Terraform execution speed?

- Created reusable modules
- Reduced duplicate code
- Ran pipeline only for changed environments
- Used targeted applies only for emergencies (not routine)

---

### 32. How do you handle multiple subscriptions?

Configured multiple provider aliases:

```hcl
provider "azurerm" {
  alias = "prod"
}
```

Each module used the correct provider alias.

---

### 33. Have you used Managed Identity?

Yes — AKS, Application Gateway, and Key Vault used Managed Identity. Terraform assigned the required RBAC roles.

---

### 34. Explain Terraform lifecycle in your project.

```
Developer
    ↓
Pull Request
    ↓
Review
    ↓
Merge
    ↓
Pipeline
    ↓
Terraform Init
    ↓
Validate
    ↓
Fmt
    ↓
Plan
    ↓
Approval
    ↓
Apply
    ↓
Infrastructure Created
```

---

### 35. Real Production Issue Interviewers Love

**Q: Terraform Apply suddenly failed after creating half the resources. What did you do?**

1. Checked Azure Portal — verified what resources were already created.
2. Ran `terraform state list` to compare with state.
3. If state was missing a resource → used `terraform import`.
4. If partial state mismatch → used `terraform refresh`.
5. Reran `terraform plan` — only remaining resources were created.
6. **Never deleted state manually.**

---

### 36. Real Challenge

**Q: What was the biggest improvement you introduced?**

> "We moved from manual Azure Portal deployments to Infrastructure as Code using Terraform. We modularized infrastructure, centralized state in Azure Blob Storage with locking, integrated Terraform into Azure DevOps pipelines with validation, formatting, plan approval, and secure authentication using Service Principals. This reduced manual errors, improved deployment consistency, enabled code reviews, and made infrastructure changes repeatable across Dev, QA, and Production environments."

---

### 37. Scenario-Based Questions

Practice list — commonly asked for 4–6 year Azure DevOps/Terraform roles:

1. A developer accidentally modified an NSG rule in the Azure Portal. How would Terraform detect and fix it?
2. Your `terraform apply` fails because a resource with the same name already exists. How would you resolve it?
3. How would you migrate an existing manually created Azure environment to Terraform without downtime?
4. How would you deploy the same AKS architecture to three subscriptions using one codebase?
5. A production `terraform apply` fails midway. What are your recovery steps?
6. How would you safely rename a Terraform resource without recreating it? (moved blocks / `terraform state mv`)
7. How do you ensure Terraform changes are reviewed before deployment?
8. How do you prevent accidental deletion of critical Azure resources?
9. How would you handle provider version upgrades in a production environment?
10. When would you use a data block instead of creating a resource?

> These questions test not just Terraform syntax, but understanding of enterprise workflows, Azure integration, operational challenges, and production troubleshooting.

---

## Part B — Deep Dive Topics

### 38. What are different types of Terraform Modules?

Terraform officially has three types of modules:

| Module Type | Description | Example |
|---|---|---|
| **Root Module** | Main module from where Terraform execution starts | `terraform apply` in root folder |
| **Child Module** | Reusable module called by the root module | AKS module, VNet module |
| **Registry Module** | Modules downloaded from Terraform Registry or Git | Azure AVM modules |

#### 1. Root Module

The directory where you execute Terraform commands:

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

This is the Root Module.

#### 2. Child Module

Reusable modules:

```
modules/
└── vnet/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
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

#### 3. Registry Module

Downloaded automatically:

```hcl
module "aks" {
  source  = "Azure/aks/azurerm"
  version = "9.0.0"
}
```

Terraform downloads it from the Terraform Registry.

#### Interview Answer

> "We mainly used Child Modules developed internally for networking, AKS, Key Vault, ACR, Monitoring, and Application Gateway. We also evaluated Azure Verified Modules (AVM) from the Terraform Registry for standard resources."

---

### 39. count vs for_each — Full Breakdown

#### `count`

Creates resources using numbers:

```hcl
resource "azurerm_resource_group" "rg" {
  count    = 3
  name     = "rg-${count.index}"
  location = "Central India"
}
```

Output: `rg-0`, `rg-1`, `rg-2`

`count.index` — current iteration number: `0, 1, 2, 3, 4...`

Access: `azurerm_resource_group.rg[0]`, `azurerm_resource_group.rg[1]`

**When to use `count`:** When resources are almost identical — e.g., three Storage Accounts, three Public IPs, three VMs.

#### `for_each`

Uses keys instead of numbers:

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = toset(["dev", "qa", "prod"])
  name     = "rg-${each.key}"
  location = "Central India"
}
```

Resources created: `rg-dev`, `rg-qa`, `rg-prod`

Access: `azurerm_resource_group.rg["dev"]`

`each.key` returns `dev`, `qa`, `prod`. `each.value` — if list, same as key; if map, returns the corresponding value.

#### Example Using a Map

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

Output:
```
rg-dev  -> Central India
rg-qa   -> South India
rg-prod -> West India
```

#### List vs Map vs Set

**List** — ordered collection:
```hcl
locals {
  names = ["dev", "qa", "prod"]
}
# local.names[0] -> dev
# local.names[1] -> qa
```

**Map** — key-value pairs:
```hcl
locals {
  location = {
    dev = "Central India"
    qa  = "South India"
  }
}
# local.location["dev"] -> Central India
```

**Set** — unique, unordered values:
```hcl
toset(["dev", "qa", "prod", "dev"])
# Output: dev, qa, prod (duplicate removed)
```

**Why `toset()`?** Terraform's `for_each` works with maps or sets. If you have a list and want to iterate over unique values, convert it to a set:

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

Terraform creates only: `rg-dev`, `rg-qa`, `rg-prod`

#### Complex Map Example (Most Asked)

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
  for_each                 = local.storage_accounts
  name                      = "st${each.key}"
  location                  = each.value.location
  account_tier              = each.value.tier
  resource_group_name       = "demo"
  account_replication_type  = "LRS"
}
```

Output:
```
stdev -> Central India, Standard
stqa  -> South India, Premium
```

#### count vs for_each (Interview Favorite)

| Feature | `count` | `for_each` |
|---|---|---|
| Uses | Numeric index | Keys (map/set) |
| Access | `count.index` | `each.key`, `each.value` |
| Best for | Identical resources | Resources with unique names/properties |
| If one item is removed | Indexes shift, may recreate resources | Only the removed key is affected |
| Enterprise preference | Less preferred | Preferred for most production use cases |

**Example — with `count`:**

```hcl
locals {
  envs = ["dev", "qa", "prod"]
}

resource "azurerm_resource_group" "rg" {
  count = length(local.envs)
  name  = "rg-${local.envs[count.index]}"
}
```

If you remove `"qa"` → `["dev", "prod"]` — the index for `prod` changes from `2` to `1`, so Terraform may destroy and recreate resources unnecessarily.

**With `for_each`:**

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = toset(["dev", "qa", "prod"])
  name     = "rg-${each.key}"
}
```

If you remove `"qa"` → `toset(["dev", "prod"])` — Terraform only removes `rg-qa`. `rg-dev` and `rg-prod` are unchanged because they're identified by keys, not indexes.

#### Interview Answer (Recommended)

> "In enterprise projects, we generally prefer for_each over count because resources are identified by stable keys rather than indexes. This avoids unnecessary resource recreation when items are added or removed from the collection. We typically use count only when creating multiple identical resources where index-based naming is acceptable."

---

### 40. How do you enable locking and versioning in Storage Account and how do you use it?

#### Interview Question

> "How do you enable locking and versioning for the Terraform state stored in an Azure Storage Account? How do you use them?"

#### Short Interview Answer

> "We store the Terraform state in an Azure Storage Account using the AzureRM backend. We enable blob versioning and soft delete on the storage account to protect the state file from accidental deletion or corruption. Terraform automatically uses Azure Blob leases for state locking during terraform apply, preventing concurrent updates. We also restrict access using RBAC and disable public access."

#### 1. Why Use Azure Storage Account?

Terraform needs a centralized state file. Instead of `terraform.tfstate` on a laptop, we store it in Azure Blob Storage.

**Benefits:**
- Shared by all engineers
- Pipeline can access it
- State locking
- Backup/versioning
- Disaster recovery

#### 2. Backend Configuration

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stterraformstate"
    container_name        = "tfstate"
    key                    = "prod/terraform.tfstate"
  }
}
```

When you run `terraform init`, Terraform connects to this blob.

#### 3. How Is Locking Enabled?

**Common misconception:** You do NOT manually enable state locking in Terraform.

When using the AzureRM backend, Terraform automatically acquires a **Blob Lease** on the state file.

```
Developer A runs: terraform apply

Terraform:
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

Now Developer B runs `terraform apply` → Terraform returns `Error acquiring the state lock`. Developer B must wait until the first operation finishes.

**Interview point:** Azure Blob Lease is the locking mechanism. Terraform manages it automatically.

#### 4. How Do You Enable Blob Versioning?

**In the Azure Portal:**

```
Storage Account
      ↓
Data Protection
      ↓
Enable:
✔ Blob Versioning
✔ Soft Delete
✔ Change Feed (optional)
✔ Point-in-Time Restore (optional)
```

**Or using Terraform:**

```hcl
resource "azurerm_storage_account" "tfstate" {
  name                      = "stterraformstate"
  resource_group_name       = "rg-tfstate"
  location                  = "Central India"
  account_tier               = "Standard"
  account_replication_type   = "LRS"

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

#### 5. Why Enable Versioning?

Suppose your state file becomes corrupted:

```
Version 1
   ↓
Version 2
   ↓
Version 3
   ↓
Version 4 (corrupted)
```

You can restore Version 3. Without versioning, state is lost and Terraform cannot track infrastructure correctly.

#### 6. How Do You Restore an Older Version?

Using the Azure Portal:

```
Storage Account
      ↓
Container
      ↓
terraform.tfstate
      ↓
Versions
      ↓
Restore
```

No Terraform commands are needed.

#### 7. What Happens During a Pipeline?

```
Azure DevOps Pipeline
        ↓
terraform init
        ↓
Reads backend
        ↓
Downloads state
        ↓
Acquires Blob Lease
        ↓
terraform plan
        ↓
terraform apply
        ↓
Updates tfstate
        ↓
Creates New Blob Version
        ↓
Releases Lease
```

This happens automatically.

#### 8. Additional Security Best Practices

In production, we also configure:

- Disable public blob access
- Use private endpoints (if required)
- Azure RBAC (`Storage Blob Data Contributor` for pipeline identity)
- Encryption at rest (enabled by Azure)
- Soft delete
- Versioning
- Least privilege access

#### 9. Real Production Scenario

**Interviewer: What if someone accidentally deletes the state file?**

If soft delete is enabled:

1. Recover the deleted blob from Azure Storage.
2. Restore the latest version.
3. Run `terraform plan` to verify the recovered state matches the infrastructure.

Without soft delete or versioning, recovery is much harder and may require rebuilding the state using `terraform import` — time-consuming and risky.

#### 10. Can We Lock the Storage Account?

**No.** We don't lock the Storage Account itself. Terraform locks only the specific blob (`terraform.tfstate`) using an Azure Blob Lease. Other blobs in the storage account remain accessible.

#### Interview Answer (Best Practice)

> "We use an Azure Storage Account as the Terraform remote backend. Blob versioning and soft delete are enabled to protect the state file and allow recovery if it's accidentally deleted or corrupted. During terraform apply, Terraform automatically acquires an Azure Blob Lease on the state file, which prevents concurrent updates by other users or pipelines. Once the operation completes, the lease is released. Access to the storage account is controlled using Azure RBAC, and public access is disabled to secure the state."

> This is the answer expected from an Azure DevOps Engineer with 4+ years of experience because it covers not only the feature, but also how it's implemented and why it's important.

---

### 41. How do you create different resources in different environments with different configurations using Terraform? (AKS example)

The enterprise approach is: **one reusable AKS module + separate environment folders + separate tfvars files.** The module stays the same; only the input variables change.

#### Project Structure

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

Notice there is only **one** AKS module.

#### Step 1: AKS Module (`modules/aks/main.tf`)

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

#### Step 2: Module Variables (`modules/aks/variables.tf`)

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

#### Step 3: DEV Environment (`environments/dev/main.tf`)

```hcl
module "aks" {
  source = "../../modules/aks"

  cluster_name    = var.cluster_name
  resource_group  = var.resource_group
  location        = var.location
  node_count      = var.node_count
  vm_size         = var.vm_size
  tags            = var.tags
}
```

#### DEV `terraform.tfvars`

```hcl
cluster_name    = "aks-dev"
resource_group  = "rg-dev"
location        = "Central India"
node_count      = 2
vm_size         = "Standard_DS2_v2"

tags = {
  Environment = "Dev"
  Owner       = "Platform"
}
```

#### QA `terraform.tfvars`

```hcl
cluster_name    = "aks-qa"
resource_group  = "rg-qa"
location        = "Central India"
node_count      = 3
vm_size         = "Standard_DS3_v2"

tags = {
  Environment = "QA"
}
```

#### PROD `terraform.tfvars`

```hcl
cluster_name    = "aks-prod"
resource_group  = "rg-prod"
location        = "Central India"
node_count      = 6
vm_size         = "Standard_D8s_v5"

tags = {
  Environment = "Production"
  Critical    = "Yes"
}
```

#### Azure DevOps Pipeline

**For Dev:**
```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

**For QA:**
```bash
terraform apply -var-file=environments/qa/terraform.tfvars
```

**For Production:**
```bash
terraform apply -var-file=environments/prod/terraform.tfvars
```

The code remains the same; only the input values differ.

#### What Changes Between Environments?

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

#### More Realistic Enterprise Example

Often, even the node pools differ:

| Environment | System Node Count | User Node Count |
|---|---|---|
| Dev | 2 | 1 |
| QA | 3 | 2 |
| Production | 5 | 10 |

The module uses variables:

```hcl
default_node_pool {
  node_count = var.system_node_count
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  node_count = var.user_node_count
}
```

#### Enterprise Improvement — Object Variables

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

Then:

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name     = var.aks_config.cluster_name
  location = var.aks_config.location
}
```

Each environment passes a different object in its `terraform.tfvars`, making the configuration cleaner and easier to maintain.

#### Interview Answer (Recommended)

> "In our project, we maintained a single reusable AKS module and separate environment folders for Dev, QA, and Production. The module contained the common AKS configuration, while each environment had its own terraform.tfvars file with values such as cluster name, node count, VM size, autoscaling limits, tags, and resource group. Our Azure DevOps pipeline selected the appropriate tfvars file based on the target environment. This allowed us to reuse the same code while provisioning different-sized AKS clusters with environment-specific configurations, reducing duplication and ensuring consistency across environments."

> This is the architecture most enterprises follow because it is scalable, maintainable, and aligns well with CI/CD practices.

---

*Document prepared for interview preparation — Terraform Azure DevOps project architecture, modules, state management, and multi-environment deployment strategy (4+ years experience level).*
