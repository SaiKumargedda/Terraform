# Terraform Advanced Interview Q&A — State Management, Modules & Production Recovery

A comprehensive reference covering Terraform state locking, drift detection, module design, refactoring, and incident recovery in an Azure enterprise context.

---

## Table of Contents

1. [State Locking & Lost Locks Mid-Apply](#1-how-does-terraform-handle-state-locking-and-what-happens-if-the-lock-is-lost-mid-apply)
2. [Plan Shows No Change, Apply Still Modifies Resources](#2-explain-a-real-scenario-where-terraform-plan-shows-no-change-but-apply-still-modifies-resources)
3. [Managing State Across Multiple Teams & Environments](#3-how-do-you-safely-manage-terraform-state-across-multiple-teams-and-environments)
4. [Multiple Modules Referencing the Same Resource](#4-what-problems-arise-when-multiple-modules-reference-the-same-resource-and-how-do-you-design-around-it)
5. [count vs for_each](#5-difference-between-count-and-for_each--and-why-switching-between-them-can-destroy-resources)
6. [Handling Secrets Without Exposing State](#6-how-do-you-handle-secrets-in-terraform-without-exposing-them-in-state-files)
7. [Drift Detection Without Downtime](#7-explain-drift-detection-how-do-you-detect-and-fix-infrastructure-drift-without-downtime)
8. [Manual Deletion Outside Terraform](#8-what-happens-internally-when-you-delete-a-resource-manually-from-azure-but-not-from-terraform)
9. [Designing Reusable, Loosely Coupled Modules](#9-how-do-you-design-terraform-modules-to-be-reusable-without-becoming-tightly-coupled)
10. [depends_on vs Implicit Dependency](#10-explain-depends_on-vs-implicit-dependency--when-does-terraform-get-it-wrong)
11. [Terraform Workspaces — Risks at Scale](#11-how-do-terraform-workspaces-actually-work-and-why-are-they-dangerous-in-large-organizations)
12. [Refactoring Without Destroying Production](#12-how-do-you-refactor-a-terraform-codebase-without-destroying-production-resources)
13. [Partial Applies & Safe Recovery](#13-what-are-partial-applies-and-how-do-you-recover-safely-from-a-failed-apply)
14. [Provider Version Mismatches](#14-how-do-provider-version-mismatches-break-production-and-how-do-you-prevent-it)
15. [State Corruption Incident Walkthrough](#15-describe-a-real-incident-caused-by-terraform-state-corruption-how-did-you-fix-it)

---

## 1. How does Terraform handle state locking, and what happens if the lock is lost mid-apply?

### What is state locking?

Terraform state maps your configuration to actual Azure resources:

```
Terraform code
     ↓
Terraform state
     ↓
Azure resources
```

If two engineers run `terraform apply` against the same state simultaneously, both could read the same state and try to modify infrastructure. **State locking prevents this.**

For an Azure enterprise setup, state is commonly stored in an Azure Storage Account Blob container, using the backend's locking mechanism so only one Terraform operation can modify a particular state at a time.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstateprod123"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
```

### What happens during `terraform apply`?

```
Engineer A
   |
terraform apply
   |
Acquire state lock
   |
Read state
   |
terraform plan
   |
Modify Azure
   |
Update state
   |
Release lock
```

If Engineer B starts another apply while A has the lock:

```
Engineer A → LOCKED → APPLYING

Engineer B → terraform apply
                  ↓
             Lock exists
                  ↓
          Error / waits depending
          on locking configuration
```

This prevents concurrent state modification.

### What if the lock is lost during apply?

```
Terraform Apply
      ↓
State locked
      ↓
Creates AKS
      ↓
Creates App Gateway
      ↓
Network operation running
      ↓
Lock/lease is lost unexpectedly
```

**Key point:** Losing the lock does not necessarily mean the infrastructure operation immediately stops. Terraform may continue executing the current resource operations. The dangerous part is that another Terraform process could acquire the lock and start working against the same state — leading to:

- Concurrent changes
- State inconsistencies
- One run overwriting state information from another
- Terraform state no longer accurately representing Azure
- Subsequent plans showing unexpected changes

### How would I troubleshoot it?

First, **do not immediately force-unlock**. Check `terraform plan` and determine whether another Terraform process is currently running. Only if certain the original operation has terminated and the lock is stale would you consider:

```bash
terraform force-unlock <LOCK_ID>
```

`force-unlock` is dangerous because if another legitimate apply is still running, it could allow concurrent operations.

### Interview Answer

> "In our Azure environment, Terraform state is stored remotely in an Azure Storage Account. State locking prevents two Terraform operations from modifying the same state simultaneously. During an apply, Terraform acquires the lock, reads the state, makes the infrastructure changes and updates the state before releasing the lock. If the lock is lost mid-apply, the current operation may continue, but the major risk is that another Terraform operation could acquire the lock and operate on the same state. I would first verify whether the original process is still running and inspect the state and Azure resources. I would use force-unlock only after confirming that the lock is stale."

---

## 2. Explain a real scenario where Terraform plan shows no change, but apply still modifies resources.

Normally, `terraform plan` and `terraform apply` should produce the same execution plan. If plan showed no changes but apply modified resources, investigate what changed between the plan and apply.

### Scenario 1 — Plan and apply executed at different times

```
10:00 AM — terraform plan → No changes
10:10 AM — Azure Portal → modifies App Gateway configuration
10:15 AM — terraform apply
```

Terraform performs a refresh/reconciliation during apply and can detect the new state — so infrastructure may change even though the earlier plan showed no changes.

### Scenario 2 — Saved plan vs normal apply

A safer CI/CD workflow:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform applies the exact saved plan rather than generating a new one — preferable for production pipelines.

### Scenario 3 — Provider/API behavior

```
Terraform configuration
        ↓
Terraform provider
        ↓
Azure API
        ↓
Actual returned values
```

Azure APIs may return values not fully known during planning, or normalized by the provider — determined only during apply.

### Scenario 4 — External changes

Someone changes an NSG rule manually. The plan generated before the change won't know about it. When apply runs later, Terraform can refresh and reconcile.

### Best Practice — Production Pipeline

```
PR
 ↓
terraform fmt
 ↓
terraform validate
 ↓
terraform plan
 ↓
Review
 ↓
Save plan
 ↓
Approval
 ↓
terraform apply saved-plan
```

### Interview Answer

> "Terraform plan and apply normally use the same desired configuration, so if an earlier plan shows no changes but a later apply modifies resources, I first check whether anything changed between the two operations. For example, an engineer may have modified an Azure resource manually after the plan was generated. During apply, Terraform can refresh the infrastructure and detect that drift. Provider behavior and values only known during apply can also contribute. In production, I prefer generating a saved plan using `terraform plan -out=tfplan` and then applying that exact plan after approval."

---

## 3. How do you safely manage Terraform state across multiple teams and environments?

Never keep production state locally on an engineer's laptop.

### Enterprise Structure

```
Azure Storage Account
        |
        +── tfstate container
              |
              +── dev.tfstate
              +── qa.tfstate
              +── prod.tfstate
```

Or preferably, separate state keys by environment/application:

```
tfstate/
├── networking/dev.tfstate
├── networking/prod.tfstate
├── aks/dev.tfstate
├── aks/prod.tfstate
├── application/dev.tfstate
└── application/prod.tfstate
```

### Why separate state?

A change in Dev shouldn't accidentally modify Production state.

### Access Control

Use Azure RBAC:

```
Terraform Pipeline Identity
        |
        ↓
Storage Account
        |
        ↓
Blob Container
        |
        ↓
Terraform State
```

Only authorized service principals/managed identities should have access.

### Protecting State

Even if a value is marked `sensitive = true`, it can still exist in the state. Therefore:

- Secure the storage account
- Restrict RBAC
- Enable encryption
- Enable soft delete/versioning where appropriate
- Restrict access to the storage account
- Never commit `.tfstate` to Git
- Don't expose state through pipeline logs

### Team Separation

```
Developer
   ↓
Git PR
   ↓
Terraform Plan
   ↓
Reviewer
   ↓
Approval
   ↓
Terraform Apply
```

Rather than allowing everyone to execute production Terraform locally.

### Interview Answer

> "For multiple teams and environments, I use remote state rather than local state. In Azure, I typically use an Azure Storage Account with separate state keys for environments or application components. Access is controlled through Azure RBAC and preferably pipeline identities. Production changes go through CI/CD with plan, review and approval rather than engineers running apply directly from their laptops. I also enable state protection such as blob versioning/soft delete where appropriate and make sure state files are never committed to source control."

---

## 4. What problems arise when multiple modules reference the same resource, and how do you design around it?

This is about **ownership**.

### The Problem

```
module.network
     ↓
creates NSG

module.aks
     ↓
also modifies NSG

module.security
     ↓
also modifies NSG
```

Multiple owners of the same resource can cause:

- Conflicting configuration
- Unexpected changes
- Hard-to-understand plans
- One module overwriting another's configuration
- Difficult troubleshooting
- Resource lifecycle problems

### Better Architecture — Single Owner Per Resource

```
module.network
    |
    +-- VNet
    +-- Subnets
    +-- NSG

module.aks
    |
    +-- AKS
    +-- Node pools

module.appgateway
    |
    +-- Application Gateway
```

Pass information through outputs:

```
network module
      |
      | subnet_id
      ↓
AKS module
```

```hcl
module "network" {
  source = "../../modules/network"
}

module "aks" {
  source = "../../modules/aks"

  subnet_id = module.network.aks_subnet_id
}
```

### Avoid Duplicate Resource Definitions

**Don't:**
```
module A → azurerm_network_security_group.main
module B → azurerm_network_security_group.main
```

**Instead:**
```
Network module owns NSG
       ↓
Other modules consume NSG ID
```

### Interview Answer

> "The main problem is unclear resource ownership. Terraform works best when a resource has a single owner in the state. If multiple modules try to create or manage the same resource, we can get conflicting configuration and unexpected plans. I normally design modules around clear ownership boundaries. For example, the network module owns the VNet, subnets and NSGs, while the AKS module consumes the subnet ID through an input variable. Modules communicate through variables and outputs rather than managing each other's resources."

---

## 5. Difference between `count` and `for_each` — and why switching between them can destroy resources

### `count`

Creates resources using numeric indexes:

```hcl
resource "azurerm_resource_group" "rg" {
  count = 3

  name = "rg-${count.index}"
}
```

Addressed as:
```
azurerm_resource_group.rg[0]
azurerm_resource_group.rg[1]
azurerm_resource_group.rg[2]
```

**Problem:** Suppose `0 → dev`, `1 → qa`, `2 → prod`. Remove `qa`:

```
0 → dev
1 → prod
```

Terraform sees `old [1] = qa`, `new [1] = prod` — so it may **destroy/recreate resources**.

### `for_each`

Uses stable keys:

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = {
    dev  = "eastus"
    qa   = "eastus"
    prod = "eastus"
  }

  name     = "rg-${each.key}"
  location = each.value
}
```

Addressed as:
```
rg["dev"]
rg["qa"]
rg["prod"]
```

Removing `qa` removes only `rg["qa"]` — other keys remain stable.

### Why Switching count → for_each Is Dangerous

```
old: resource.example[0]
new: resource.example["dev"]
```

Terraform doesn't automatically know `[0] == ["dev"]`, so it may interpret the change as **destroy old, create new**.

### Safe Migration

Use `terraform state mv` or `moved` blocks:

```hcl
moved {
  from = azurerm_resource_group.rg[0]
  to   = azurerm_resource_group.rg["dev"]
}
```

### Interview Answer

> "count uses numeric indexes while for_each uses stable keys. I prefer for_each when resources have meaningful identities because removing an element from a list can shift indexes with count. Switching from count to for_each also changes the Terraform resource address, so Terraform may think the old resource needs to be destroyed and a new one created. For production, I handle such refactoring using state moves or moved blocks and verify the plan carefully before applying."

---

## 6. How do you handle secrets in Terraform without exposing them in state files?

**Important clarification:** You cannot guarantee Terraform will never store a secret in state simply by marking it `sensitive`.

```hcl
variable "db_password" {
  sensitive = true
}
```

This prevents Terraform from displaying the value normally in CLI output — but the value can still exist in state if Terraform needs to manage it.

### Better Approach

```
Azure Key Vault
       ↓
Application
       ↓
Secret
```

For AKS:

```
Azure Key Vault
      ↓
Key Vault CSI Driver
      ↓
AKS Pod
```

Terraform provisions the infrastructure, while Key Vault manages the secret.

### Example Architecture

```
Terraform
   |
   +-- Key Vault
   +-- AKS
   +-- Managed Identity
   +-- RBAC
   |
   ↓
Key Vault
   |
   ↓
AKS CSI Driver
   |
   ↓
Pod
```

### If Terraform Itself Needs a Secret

```hcl
admin_password = var.admin_password
```

That value may end up in state. Therefore:

- Don't commit tfstate
- Use remote secured backend
- Restrict state access
- Use Key Vault/external secret systems
- Use pipeline secret variables
- Mark Terraform variables as sensitive
- Avoid printing secrets in pipeline logs

### Interview Answer

> "I don't treat sensitive = true as a mechanism that removes secrets from state. It mainly prevents the value from being displayed in Terraform output. If Terraform manages a resource attribute containing a secret, the value may still be stored in state. Therefore, wherever possible, I keep application secrets in Azure Key Vault and let AKS consume them using managed identity and the Key Vault CSI driver. For secrets that Terraform genuinely needs, I protect the remote state with RBAC and encryption and ensure secrets aren't exposed through Git or pipeline logs."

---

## 7. Explain drift detection. How do you detect and fix infrastructure drift without downtime?

### What is drift?

```
Terraform configuration
        ≠
Actual Azure infrastructure
```

Example: Terraform says `AKS node count = 3`, but someone manually changes Azure to `node count = 5`. That's drift.

### Detection

Run `terraform plan`. Terraform refreshes resource information from the provider and compares:

```
Configuration → State → Actual Azure infrastructure
```

If the plan shows `~ node_count = 5 -> 3`, Terraform has detected drift.

### How to Fix It

First determine whether the manual change was **intentional** or **unintentional**.

- **Intentional:** Update Terraform configuration (`node_count = 5`) and apply.
- **Unintentional:** Terraform should restore the desired state — but always run `terraform plan` first to verify exactly what will change.

### Avoiding Downtime

Don't blindly run `terraform apply`. Check whether Terraform wants an **in-place update** or a **destroy + recreate**. If destructive, investigate first.

For AKS, consider:
- Multiple nodes
- Multiple availability zones where supported
- PodDisruptionBudget
- Multiple replicas
- Rolling upgrades
- Proper readiness probes

For Application Gateway/Front Door:

```
Users → Front Door → App Gateway → AKS
```

Changes can be made in a way that maintains service availability.

### Interview Answer

> "Drift occurs when the real Azure infrastructure differs from the Terraform configuration. I detect it through terraform plan, which refreshes resource information and compares it against the desired configuration. I first determine whether the drift was intentional or accidental. If intentional, I update Terraform so it doesn't continually try to revert it. If accidental, I review the plan and restore the desired configuration. For production I specifically check whether the correction is in-place or destructive and use HA mechanisms such as multiple AKS replicas, PDBs and rolling changes to avoid downtime."

---

## 8. What happens internally when you delete a resource manually from Azure but not from Terraform?

Suppose Terraform manages `azurerm_resource_group.app`, and state contains the Azure Resource ID. Someone deletes it from the Azure Portal.

Terraform state still thinks the resource exists; Azure says it doesn't.

### What Happens During Plan?

Terraform refreshes the resource — asks Azure "Does resource ID XYZ exist?" Azure responds `404 Not Found`.

Terraform realizes:
```
State says EXISTS
Actual infrastructure says DOES NOT EXIST
```

Terraform then plans to **recreate** it:

```
Plan:
+ create azurerm_resource_group.app
```

**Important:** Terraform doesn't blindly trust state — the provider refreshes resource information.

### If the Resource Was Deleted Intentionally

Remove it from Terraform state:

```bash
terraform state rm <resource-address>
```

This should only be done when you intentionally want Terraform to stop managing that resource.

### Interview Answer

> "If I manually delete an Azure resource that's still present in Terraform state, the state becomes stale. During the next plan, Terraform refreshes the resource through the Azure provider. Since Azure returns that the resource no longer exists, Terraform recognizes that the managed resource is missing and normally proposes recreating it. If the deletion was intentional and Terraform should no longer manage that resource, I would remove it from Terraform state using terraform state rm, after carefully verifying the resource address."

---

## 9. How do you design Terraform modules to be reusable without becoming tightly coupled?

A good module has a clean flow: `Inputs → Module → Outputs`. It shouldn't know too much about its surrounding environment.

### Bad Module

```hcl
location = "East US"
resource_group = "prod-rg"
subnet_id = "/subscriptions/xxx/..."
```

Tightly coupled to one environment — can't easily be reused.

### Better Module

```hcl
variable "cluster_name" {}
variable "location" {}
variable "resource_group_name" {}
variable "subnet_id" {}
variable "node_count" {}
```

```hcl
module "aks" {
  source = "../../modules/aks"

  cluster_name         = "aks-dev"
  location             = "East US"
  resource_group_name  = module.rg.name
  subnet_id            = module.network.aks_subnet_id
  node_count           = 3
}
```

### Outputs

The module should expose useful information:

```hcl
output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
```

Other modules can consume these outputs.

### Good Module Layout

```
modules/
├── network/
├── aks/
├── appgateway/
├── keyvault/
└── monitoring/
```

Each module should have a clear responsibility.

### Avoid Over-Modularization

Don't create excessive fragmentation like `module.nsg-rule-1`, `module.nsg-rule-2`, etc. if it makes the architecture impossible to understand.

### Interview Answer

> "I design modules around clear responsibilities and expose configuration through variables and outputs. I avoid hardcoded subscription IDs, resource names, environments and locations inside reusable modules. For example, my AKS module accepts the subnet ID, resource group name, location and node-pool configuration as inputs. The network module owns networking and exposes subnet IDs through outputs. This keeps modules loosely coupled while still allowing them to work together."

---

## 10. Explain `depends_on` vs implicit dependency — when does Terraform get it wrong?

Terraform builds a dependency graph.

### Implicit Dependency

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-app"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-app"
  resource_group_name = azurerm_resource_group.rg.name
}
```

Terraform sees `AKS → Resource Group` because AKS references `azurerm_resource_group.rg.name`. Terraform automatically understands this — it's an **implicit dependency**.

### When Terraform Cannot Understand It

```
Resource A
     ↓
Azure configuration outside Terraform
     ↓
Resource B
```

There may be a real dependency, but Terraform doesn't see a reference between the resources. Then explicitly define it:

```hcl
depends_on = [
  azurerm_resource_group.rg
]
```

### Example

```hcl
resource "azurerm_some_resource" "app" {
  # configuration

  depends_on = [
    azurerm_role_assignment.identity
  ]
}
```

### Don't Overuse `depends_on`

```hcl
depends_on = [
  module.network,
  module.security,
  module.monitoring,
  module.aks
]
```

This is bad when Terraform could already infer dependencies — it unnecessarily restricts the dependency graph and can cause longer plans/applies.

### Interview Answer

> "Terraform automatically creates implicit dependencies when one resource references another resource's attributes. I use depends_on only when there's a real dependency that Terraform cannot infer from the configuration, such as an ordering requirement involving a side effect or external behavior. I avoid using depends_on everywhere because it can unnecessarily serialize operations and make the dependency graph harder to maintain."

---

## 11. How do Terraform workspaces actually work, and why are they dangerous in large organizations?

Terraform workspaces allow multiple state instances for the same configuration:

```
Same Terraform code
       |
       +---- dev state
       |
       +---- qa state
       |
       +---- prod state
```

### Why People Use Them

Instead of separate `dev/`, `qa/`, `prod/` directories:

```bash
terraform workspace select dev
terraform apply

terraform workspace select prod
terraform apply
```

### Why Dangerous?

The biggest problem is **human error**. An engineer may think they're in the `dev` workspace but actually be in `prod`, then run `terraform apply` and potentially modify Production.

### Another Issue

Large organizations often have different requirements per environment (different variables, networking, security, approvals, pipelines). Relying on workspace switching alone makes it easy to accidentally use the wrong configuration.

### Enterprise Approach

```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── backend.tf
│
├── qa/
│
└── prod/
```

with shared modules:

```
modules/
├── aks/
├── network/
├── appgateway/
└── monitoring/
```

This provides stronger separation.

### Interview Answer

> "Terraform workspaces provide separate state instances for the same configuration, which can be useful for simple environment separation. However, I consider them risky for large organizations because engineers can accidentally select the wrong workspace and run an apply against production. Production may also have significantly different configuration, security and approval requirements. For enterprise Azure environments, I prefer separate environment directories with shared reusable modules and separate remote state, combined with CI/CD approvals."

---

## 12. How do you refactor a Terraform codebase without destroying production resources?

Suppose we initially have a flat `main.tf` with `azurerm_kubernetes_cluster.aks`, and want to move it into `modules/aks/`.

If we simply move the resource code:

```
OLD ADDRESS: azurerm_kubernetes_cluster.aks
NEW ADDRESS: module.aks.azurerm_kubernetes_cluster.aks
```

Terraform could interpret this as **destroy old, create new** — dangerous for production.

### Solution: State-Aware Refactoring

```hcl
moved {
  from = azurerm_kubernetes_cluster.aks
  to   = module.aks.azurerm_kubernetes_cluster.aks
}
```

Terraform understands the old address is the same resource at the new address — no infrastructure destruction required.

Alternatively, use `terraform state mv`.

### Safe Process

```
1. Create branch
       ↓
2. Refactor code
       ↓
3. Add moved blocks/state moves
       ↓
4. terraform fmt
       ↓
5. terraform validate
       ↓
6. terraform plan
       ↓
7. Verify NO destroy/recreate
       ↓
8. PR review
       ↓
9. Apply
```

### Most Important Rule

Never assume "it's just a code refactor" — Terraform cares about resource addresses.

### Interview Answer

> "When refactoring Terraform, my biggest concern is preserving resource identity. Moving a resource from the root module into a child module changes its Terraform address. Without telling Terraform that the address changed, it may interpret the change as destroy and recreate. I use moved blocks or terraform state mv to map the old address to the new address. Before applying, I run a plan and verify that production resources show no unexpected destroy or replacement actions."

---

## 13. What are partial applies, and how do you recover safely from a failed apply?

Terraform doesn't provide a traditional database-style transaction (all-succeed or full rollback).

### Example

Terraform needs to create: VNet → AKS → Application Gateway → Monitoring → Key Vault.

```
VNet              ✅
AKS               ✅
Application GW    ❌
Monitoring        ⏸
Key Vault         ⏸
```

This is a **partial apply**. Terraform doesn't automatically delete the successfully created VNet and AKS.

### What Happens to State?

Terraform records successful operations into state, so after failure:

```
Terraform state
    ↓
VNet exists
AKS exists
App Gateway may not exist
```

### Recovery Process

1. **Don't** immediately rerun random commands.
2. Run `terraform plan` — understand what succeeded, what failed, what exists in Azure, and what's in state.
3. Fix the root cause (e.g., subnet delegation/configuration issue for App Gateway).
4. `terraform plan` → `terraform apply` — Terraform should continue from current state rather than recreate existing resources.

### If a Resource Exists But Isn't in State

Use `terraform import`.

### Avoid Blindly Using `-target`

`-target` can be useful for exceptional recovery, but should not become the normal deployment strategy — it can bypass parts of the dependency graph.

### Interview Answer

> "Terraform isn't transactional, so an apply can partially succeed. For example, the VNet and AKS may be created successfully while Application Gateway fails. Terraform records successful operations in state, but it doesn't automatically roll everything back. I first inspect the error and run terraform plan to understand the current state. I fix the root cause and rerun the normal plan/apply. If a resource exists in Azure but isn't represented in state, I may use import. I use -target only as an exceptional recovery mechanism, not as the normal deployment approach."

---

## 14. How do provider version mismatches break production, and how do you prevent it?

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

### What Can Go Wrong?

Suppose Dev uses AzureRM provider 4.x while Production uses 3.x — the same Terraform code might behave differently.

Provider versions can introduce:

- New required arguments
- Deprecated arguments
- Changed defaults
- Resource behavior changes
- Schema changes
- Different API behavior

### `.terraform.lock.hcl`

A developer runs `terraform init -upgrade`, gets a new provider version, then commits `.terraform.lock.hcl`. CI/CD uses the locked version — this is good practice. The lock file records provider selections/checksums so environments use consistent provider versions.

### Best Practice

- Pin provider versions with `required_providers`
- Commit `.terraform.lock.hcl` to Git
- Test upgrades in Dev → QA → Production, instead of upgrading directly in Production

### Interview Answer

> "Provider version mismatches can cause production differences because provider releases can change resource schemas, defaults and behavior. I prevent this by defining provider constraints in required_providers and committing .terraform.lock.hcl so CI/CD and engineers use the same tested provider version. When upgrading a provider, I test it in lower environments first, review the Terraform plan carefully and then promote the tested version to production."

---

## 15. Describe a real incident caused by Terraform state corruption. How did you fix it?

*This is a behavioral + technical interview question. Present it as a realistic production scenario rather than claiming a specific personal incident if it didn't occur.*

### Scenario

Terraform state is stored remotely in Azure Blob Storage. An engineer accidentally runs Terraform against the wrong backend/state, or a state update is interrupted. The state becomes inconsistent with Azure.

```
Azure:
AKS exists
App Gateway exists
VNet exists

Terraform state:
AKS exists
App Gateway missing
VNet exists
```

A subsequent plan could propose `+ create Application Gateway`, but the Azure API may respond "Resource already exists" — a state/infrastructure mismatch.

### First Thing NOT to Do

Do **not** immediately execute `terraform apply` — the state's trustworthiness is unknown. First run `terraform plan` and inspect the state.

### Step 1 — Stop Concurrent Terraform Operations

Temporarily halt CI/CD deployments to prevent the problem from worsening.

### Step 2 — Backup Current State

Preserve the current state before making modifications. With remote state, use the backend's state versioning/history if enabled — one reason to enable **blob versioning** and **soft delete** for Terraform state storage.

### Step 3 — Compare State With Azure

Determine what Terraform thinks exists vs. what actually exists in Azure using:

```bash
terraform state list
terraform state show <resource>
```

Then verify against actual Azure resources.

### Step 4 — If Resource Exists But State Doesn't

```bash
terraform import \
  azurerm_application_gateway.appgw \
  /subscriptions/.../resourceGroups/.../providers/Microsoft.Network/applicationGateways/appgw
```

Then `terraform plan`. Goal: `Terraform state ≈ Terraform configuration ≈ Azure infrastructure`.

### Step 5 — If State Itself Is Corrupted

If the remote backend has state versions/backups, restore the last known-good version — **only after confirming which version matches the infrastructure**. Don't blindly restore "yesterday's state," since Azure infrastructure may have legitimately changed since then. The goal is to recover a state representation that accurately matches the *existing* infrastructure, not simply an old file.

### Step 6 — Validate

```bash
terraform init
terraform plan
```

Ideally: no unexpected changes, or only the changes intentionally expected.

### Interview Answer

> "A realistic state corruption incident would be where the Terraform state no longer accurately represented Azure infrastructure. For example, an Application Gateway existed in Azure but was missing from the Terraform state, so Terraform planned to create a duplicate resource. I would first stop concurrent deployments and preserve the current state rather than immediately applying. I would compare terraform state list and terraform state show with the actual Azure resources. If the resource existed in Azure but was missing from state, I would use terraform import to reconcile it. If the state itself was corrupted, I would use the Azure Storage backend's state versioning to identify and recover the last known-good state, after verifying it matched the infrastructure. Finally, I would run terraform plan and ensure there were no unexpected destroy or recreate operations before allowing production deployment."

---

*Document prepared for interview preparation — Terraform state management, module design, and production incident recovery in Azure enterprise environments.*
