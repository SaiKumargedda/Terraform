Terraform Azure Interview Questions (4+ Years)
1. Explain your Terraform project architecture.
Answer

Our Terraform code was organized in a modular structure.

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

Each environment only passed different tfvars.

We reused the same modules across all environments.

2. Why did you use modules?
Answer

Modules helped us

avoid duplicate code
standardize infrastructure
simplify maintenance
version infrastructure
improve reusability

Example

Instead of writing AKS creation three times,

we created one AKS module

and reused it for Dev, QA and Production.

3. Which Azure resources did you create using Terraform?

Example answer

We provisioned

Resource Groups
VNets
Subnets
NSGs
AKS
ACR
Azure Key Vault
Log Analytics Workspace
Application Insights
Azure Monitor Alerts
Managed Identity
Role Assignments
Application Gateway
Public IP
Azure DNS
Private Endpoints
Storage Account for tfstate
4. Where was your Terraform State stored?

Answer

Terraform state was stored in Azure Storage Account Blob Container.

Backend configuration

Storage Account

Container

tfstate file

State locking was automatically handled through Azure Blob lease mechanism.

5. Why remote backend?

Answer

Because

Multiple engineers worked together.

Without remote backend,

everyone would have different state files.

Remote backend

stores centralized state
supports locking
enables collaboration
prevents corruption
6. Explain state locking.

Answer

Suppose

Developer A is running

terraform apply

Terraform acquires a blob lease.

Developer B cannot modify infrastructure until lease is released.

This prevents concurrent updates.

7. How did you manage different environments?

Answer

We maintained

dev.tfvars

qa.tfvars

prod.tfvars

Pipeline passed

terraform apply -var-file=prod.tfvars

Same code

Different variables

Different environments.

8. Did you use Terraform Workspaces?

Answer

No.

We avoided workspaces because

Environment isolation becomes difficult.

Instead

we maintained separate folders

environments/dev

environments/qa

environments/prod

which is Microsoft's recommended enterprise approach.

9. How did Terraform integrate with Azure DevOps?

Answer

Pipeline stages

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


Authentication happened through Azure Service Connection using Service Principal.

10. How did Terraform authenticate to Azure?

Answer

Azure DevOps Service Connection

↓

Azure Service Principal

↓

Contributor permissions on subscription/resource group.

Terraform automatically used ARM credentials.

11. What improvements did you implement?

Expected interview question

Answer

We introduced

✔ Modular Terraform

✔ Remote backend

✔ Version pinning

✔ Pipeline approvals

✔ Automatic formatting

terraform fmt

✔ Validation

terraform validate

✔ Plan artifact publishing

✔ Code review before Apply

✔ Separate tfvars

✔ Resource tagging

✔ Naming conventions

✔ Secrets moved to Azure Key Vault

12. Biggest Terraform challenge?

Example answer

Initially

developers were applying infrastructure from laptops.

Problems

Different provider versions

Different state files

No approvals

Manual mistakes

We improved it by

Running Terraform only through Azure DevOps pipeline.

13. Another challenge?

Answer

Terraform state corruption.

Reason

Someone interrupted apply.

Solution

Recovered state

Used

terraform refresh

Imported missing resources

terraform import

and enabled state locking.

14. Have you imported existing Azure resources?

Answer

Yes.

Existing production resources

were imported.

Example

terraform import azurerm_resource_group.demo \
/subscriptions/xxx/resourceGroups/demo

After import

Terraform started managing those resources.

15. Difference between Refresh and Import?

Refresh

Updates Terraform state.

Import

Adds existing resource into Terraform state.

16. How do you detect infrastructure drift?

Answer

Using

terraform plan

If someone modifies Azure Portal manually,

Terraform detects differences.

17. What happens if someone deletes AKS manually?

Answer

Next

terraform plan

shows

AKS will be created.

Terraform tries to bring infrastructure back.

18. How did you protect production resources?

Answer

Used

lifecycle {

prevent_destroy=true

}

Critical resources

Storage

Key Vault

Database

couldn't be accidentally destroyed.

19. Why ignore_changes?

Example

lifecycle {

ignore_changes = [
tags
]

}

Azure automatically updates tags sometimes.

Terraform shouldn't recreate resource unnecessarily.

20. Explain depends_on.

Answer

Sometimes Terraform cannot infer dependency.

Example

AKS

needs

Role Assignment first.

depends_on

ensures correct creation order.

21. What Azure-specific dependencies did you manage?

Example

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

Terraform dependency chain ensured proper provisioning.

22. How do you manage secrets?

Answer

Never stored secrets inside tfvars.

Secrets came from

Azure Key Vault

or

Azure DevOps Variable Groups.

23. How did you handle Terraform versions?

Answer

Used

required_version

and

required_providers

to avoid version mismatch.

24. Explain provider version pinning.
terraform {

required_providers {

azurerm = {

version="~>4.0"

}

}

}

This avoids unexpected provider upgrades.

25. What happens if provider version changes?

Answer

New provider may

change API behavior

deprecate resources

change attributes

So we tested provider upgrades in lower environments first.

26. How do you rollback Terraform?

Answer

Terraform has no rollback.

Rollback means

Restore previous code

↓

Run

terraform apply

Infrastructure becomes previous version.

27. How do you review Terraform changes?

Answer

Terraform Plan

↓

Publish Plan Artifact

↓

Reviewer checks

↓

Approval

↓

Terraform Apply

28. Have you used data blocks?

Example

Instead of creating VNet

data "azurerm_virtual_network"

to read existing infrastructure.

Useful when networking team owns VNet.

29. What is the difference between resource and data?

Resource

Creates infrastructure.

Data

Reads existing infrastructure.

30. What is Terraform taint?
terraform taint resource

Marks resource for recreation.

Next apply recreates only that resource.

31. How did you improve Terraform execution speed?

Answer

Created reusable modules.

Reduced duplicate code.

Ran pipeline only for changed environments.

Used targeted applies only for emergencies (not routine).

32. How do you handle multiple subscriptions?

Answer

Configured multiple provider aliases.

provider "azurerm" {

alias="prod"

}

Each module used correct provider alias.

33. Have you used Managed Identity?

Answer

Yes.

AKS

Application Gateway

Key Vault

used Managed Identity.

Terraform assigned required RBAC roles.

34. Explain Terraform lifecycle in your project.
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

35. Real Production Issue Interviewers Love

Q: Terraform Apply suddenly failed after creating half the resources. What did you do?

Answer

First

Checked Azure Portal.

Verified what resources were already created.

Ran

terraform state list

to compare state.

If state missing,

used

terraform import

If partial state mismatch,

used

terraform refresh

Then reran

terraform plan

Only remaining resources were created.

Never deleted state manually.

36. Real Challenge

Q: What was the biggest improvement you introduced?

Example answer

We moved from manual Azure Portal deployments to Infrastructure as Code using Terraform. We modularized infrastructure, centralized state in Azure Blob Storage with locking, integrated Terraform into Azure DevOps pipelines with validation, formatting, plan approval, and secure authentication using Service Principals. This reduced manual errors, improved deployment consistency, enabled code reviews, and made infrastructure changes repeatable across Dev, QA, and Production environments.

37. Scenario-Based Questions
A developer accidentally modified an NSG rule in the Azure Portal. How would Terraform detect and fix it?
Your terraform apply fails because a resource with the same name already exists. How would you resolve it?
How would you migrate an existing manually created Azure environment to Terraform without downtime?
How would you deploy the same AKS architecture to three subscriptions using one codebase?
A production terraform apply fails midway. What are your recovery steps?
How would you safely rename a Terraform resource without recreating it? (using moved blocks or terraform state mv)
How do you ensure Terraform changes are reviewed before deployment?
How do you prevent accidental deletion of critical Azure resources?
How would you handle provider version upgrades in a production environment?
When would you use a data block instead of creating a resource?

These are the types of questions most commonly asked for a 4–6 year Azure DevOps/Terraform engineer, especially when Terraform is a major part of the role. They test not just Terraform syntax, but your understanding of enterprise workflows, Azure integration, operational challenges, and production troubleshooting.

These are very common Terraform interview questions. I'll explain them from an Azure DevOps (4+ years) perspective.

1. What are different types of Terraform Modules?

Terraform officially has three types of modules.

Module Type	Description	Example
Root Module	Main module from where Terraform execution starts	terraform apply in root folder
Child Module	Reusable module called by root module	AKS module, VNet module
Registry Module	Modules downloaded from Terraform Registry or Git	Azure AVM modules
1. Root Module

This is the directory where you execute Terraform commands.

terraform/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf

Example

module "vnet" {
  source = "./modules/vnet"

  resource_group_name = var.rg
}

This is the Root Module.

2. Child Module

These are reusable modules.

modules/

   vnet/

      main.tf
      variables.tf
      outputs.tf

Example

resource "azurerm_virtual_network" "vnet" {

  name                = var.name
  address_space       = var.address_space
  resource_group_name = var.rg
}

Then called from root.

module "network" {

 source="./modules/vnet"

}
3. Registry Module

Downloaded automatically.

Example

module "aks" {

source="Azure/aks/azurerm"

version="9.0.0"

}

Terraform downloads it from Terraform Registry.

Interview Question
Which module type did you use?

Answer:

We mainly used Child Modules developed internally for networking, AKS, Key Vault, ACR, Monitoring, and Application Gateway. We also evaluated Azure Verified Modules (AVM) from the Terraform Registry for standard resources.

count

Creates resources using numbers.

Example

Create 3 Resource Groups.

resource "azurerm_resource_group" "rg" {

count = 3

name="rg-${count.index}"

location="Central India"

}

Output

rg-0

rg-1

rg-2
count.index

Current iteration number.

0

1

2

3

4
Access
azurerm_resource_group.rg[0]

azurerm_resource_group.rg[1]
When do we use Count?

When resources are almost identical.

Example

Three Storage Accounts

Three Public IPs

Three VMs

for_each

Uses keys instead of numbers.

Example

resource "azurerm_resource_group" "rg" {

for_each = toset([
"dev",
"qa",
"prod"
])

name="rg-${each.key}"

location="Central India"

}

Resources created

rg-dev

rg-qa

rg-prod

Access

azurerm_resource_group.rg["dev"]
each.key

Returns

dev

qa

prod
each.value

If list

dev

qa

prod

If map

returns corresponding value.

Example using Map
locals {

resource_groups={

dev="Central India"

qa="South India"

prod="West India"

}

}

Create RGs

resource "azurerm_resource_group" "rg" {

for_each=local.resource_groups

name="rg-${each.key}"

location=each.value

}

Output

rg-dev -> Central India

rg-qa -> South India

rg-prod -> West India
Difference
each.key

dev

qa

prod
each.value

Central India

South India

West India
List

Ordered collection.

locals {

names=[
"dev",
"qa",
"prod"
]

}

Access

local.names[0]

local.names[1]

Output

dev

qa

Map

Key value pair.

locals {

location={

dev="Central India"

qa="South India"

}

}

Access

local.location["dev"]

Output

Central India
Set

Unique unordered values.

toset([
"dev",
"qa",
"prod",
"dev"
])

Output

dev

qa

prod

Duplicate removed.

Why toset()?

Terraform's for_each works with maps or sets. If you have a list and want to iterate over unique values, convert it to a set.

Example

locals {
  envs = ["dev", "qa", "prod", "dev"]
}

resource "azurerm_resource_group" "rg" {

  for_each = toset(local.envs)

  name     = "rg-${each.key}"
  location = "Central India"
}

Terraform creates only:

rg-dev
rg-qa
rg-prod
Complex Map Example (Most Asked)
locals {

storage_accounts = {

dev = {

location = "Central India"

tier = "Standard"

}

qa = {

location = "South India"

tier = "Premium"

}

}

}

Resource

resource "azurerm_storage_account" "storage" {

for_each=local.storage_accounts

name="st${each.key}"

location=each.value.location

account_tier=each.value.tier

resource_group_name="demo"

account_replication_type="LRS"

}

Output

stdev

Central India

Standard
stqa

South India

Premium
count vs for_each (Interview Favorite)
Feature	count	for_each
Uses	Numeric index	Keys (map/set)
Access	count.index	each.key, each.value
Best for	Identical resources	Resources with unique names/properties
If one item is removed	Indexes shift, which may recreate resources	Only the removed key is affected
Enterprise preference	Less preferred	Preferred for most production use cases
Example

With count:

locals {
  envs = ["dev", "qa", "prod"]
}
resource "azurerm_resource_group" "rg" {
  count = length(local.envs)
  name  = "rg-${local.envs[count.index]}"
}

If you remove "qa":

["dev", "prod"]

The index for prod changes from 2 to 1, so Terraform may destroy and recreate resources unnecessarily.

With for_each:

resource "azurerm_resource_group" "rg" {

  for_each = toset(["dev","qa","prod"])

  name = "rg-${each.key}"
}

If you remove "qa":

toset(["dev","prod"])

Terraform only removes rg-qa. rg-dev and rg-prod are unchanged because they are identified by their keys, not by numeric indexes.

Interview Answer (Recommended)

In enterprise projects, we generally prefer for_each over count because resources are identified by stable keys rather than indexes. This avoids unnecessary resource recreation when items are added or removed from the collection. We typically use count only when creating multiple identical resources where index-based naming is acceptable.

how do you eanble locking and versioning in storage account and how you use it 

This is an excellent Azure + Terraform interview question. Interviewers often ask it because storing the Terraform state securely is critical in production.

Interview Question

How do you enable locking and versioning for the Terraform state stored in an Azure Storage Account? How do you use them?

Short Interview Answer

We store the Terraform state in an Azure Storage Account using the AzureRM backend. We enable blob versioning and soft delete on the storage account to protect the state file from accidental deletion or corruption. Terraform automatically uses Azure Blob leases for state locking during terraform apply, preventing concurrent updates. We also restrict access using RBAC and disable public access.

1. Why do we use Azure Storage Account?

Terraform needs a centralized state file.

Instead of:

terraform.tfstate

on your laptop,

we store it in Azure Blob Storage.

Benefits:

Shared by all engineers
Pipeline can access it
State locking
Backup/versioning
Disaster recovery
2. Backend Configuration

Example:

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}

When you run:

terraform init

Terraform connects to this blob.

3. How is Locking Enabled?

This is a common misconception.

You do NOT manually enable state locking in Terraform.

When using the AzureRM backend, Terraform automatically acquires a Blob Lease on the state file.

Example:

Developer A runs:

terraform apply

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

Now Developer B runs:

terraform apply

Terraform returns:

Error acquiring the state lock

Developer B must wait until the first operation finishes.

Interview Point

Azure Blob Lease is the locking mechanism. Terraform manages it automatically.

4. How do you Enable Blob Versioning?

In the Azure Portal:

Storage Account

↓

Data Protection

↓

Enable

✔ Blob Versioning

✔ Soft Delete

✔ Change Feed (optional)

✔ Point-in-Time Restore (optional)

Or using Terraform:

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
5. Why Enable Versioning?

Suppose your state file becomes corrupted.

Current blob:

terraform.tfstate

Version History:

Version 1

↓

Version 2

↓

Version 3

↓

Version 4

If Version 4 is corrupted,

you can restore Version 3.

Without versioning:

State Lost

↓

Terraform cannot track infrastructure correctly.
6. How do You Restore an Older Version?

Using the Azure Portal:

Storage Account

↓

Container

↓

terraform.tfstate

↓

Versions

↓

Restore

No Terraform commands are needed.

7. What Happens During a Pipeline?
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

This happens automatically.

8. Additional Security Best Practices

In production we also configure:

Disable public blob access
Use private endpoints (if required)
Azure RBAC (Storage Blob Data Contributor for pipeline identity)
Encryption at rest (enabled by Azure)
Soft delete
Versioning
Least privilege access
9. Real Production Scenario

Interviewer: What if someone accidentally deletes the state file?

Answer

If soft delete is enabled:

Recover the deleted blob from Azure Storage.
Restore the latest version.
Run terraform plan to verify the recovered state matches the infrastructure.

Without soft delete or versioning, recovery is much harder and may require rebuilding the state using terraform import, which is time-consuming and risky.

10. Can We Lock the Storage Account?

No.

We don't lock the Storage Account itself.

Terraform locks only the specific blob (terraform.tfstate) using an Azure Blob Lease.

Other blobs in the storage account remain accessible.

Interview Answer (Best Practice)

"We use an Azure Storage Account as the Terraform remote backend. Blob versioning and soft delete are enabled to protect the state file and allow recovery if it's accidentally deleted or corrupted. During terraform apply, Terraform automatically acquires an Azure Blob Lease on the state file, which prevents concurrent updates by other users or pipelines. Once the operation completes, the lease is released. Access to the storage account is controlled using Azure RBAC, and public access is disabled to secure the state."

This is the answer expected from an Azure DevOps Engineer with 4+ years of experience because it covers not only the feature, but also how it's implemented and why it's important.

how do you create diff resources in diff env with diff configurayions using terraform give aks as exmple how you create 

This is one of the most frequently asked Terraform interview questions. Interviewers want to know if you understand module reuse and environment-specific configuration without duplicating code.

The enterprise approach is:

One reusable AKS module + separate environment folders + separate tfvars files. The module stays the same; only the input variables change.

Project Structure
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

Notice that there is only one AKS module.

Step 1: AKS Module (modules/aks/main.tf)
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
Step 2: Module Variables (modules/aks/variables.tf)
variable "cluster_name" {}
variable "resource_group" {}
variable "location" {}
variable "node_count" {}
variable "vm_size" {}

variable "tags" {
  type = map(string)
}
Step 3: DEV Environment (environments/dev/main.tf)
module "aks" {

  source = "../../modules/aks"

  cluster_name  = var.cluster_name
  resource_group = var.resource_group
  location      = var.location

  node_count = var.node_count
  vm_size    = var.vm_size

  tags = var.tags
}
DEV terraform.tfvars
cluster_name   = "aks-dev"

resource_group = "rg-dev"

location = "Central India"

node_count = 2

vm_size = "Standard_DS2_v2"

tags = {

Environment = "Dev"

Owner = "Platform"

}
QA terraform.tfvars
cluster_name="aks-qa"

resource_group="rg-qa"

location="Central India"

node_count=3

vm_size="Standard_DS3_v2"

tags={

Environment="QA"

}
PROD terraform.tfvars
cluster_name="aks-prod"

resource_group="rg-prod"

location="Central India"

node_count=6

vm_size="Standard_D8s_v5"

tags={

Environment="Production"

Critical="Yes"

}
Azure DevOps Pipeline

For Dev:

terraform apply \
-var-file=environments/dev/terraform.tfvars

For QA:

terraform apply \
-var-file=environments/qa/terraform.tfvars

For Production:

terraform apply \
-var-file=environments/prod/terraform.tfvars

The code remains the same; only the input values differ.

What Changes Between Environments?
Configuration	Dev	QA	Prod
Cluster Name	aks-dev	aks-qa	aks-prod
Node Count	2	3	6
VM Size	DS2_v2	DS3_v2	D8s_v5
Auto Scaling	Disabled/Small	Enabled	Enabled
Min Nodes	1	2	3
Max Nodes	3	5	10
Log Analytics	Shared	Dedicated	Dedicated
SKU	Free	Standard	Premium
Tags	Dev	QA	Production
More Realistic Enterprise Example

Often, even the node pools differ.

Dev
system_node_count = 2

user_node_count = 1
QA
system_node_count = 3

user_node_count = 2
Production
system_node_count = 5

user_node_count = 10

The module uses variables:

default_node_pool {
  node_count = var.system_node_count
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {

  node_count = var.user_node_count

}
Enterprise Improvement

Instead of passing many individual variables, you can use an object variable.

variable "aks_config" {

type = object({

cluster_name = string

node_count = number

vm_size = string

location = string

})

}

Then:

resource "azurerm_kubernetes_cluster" "aks" {

name = var.aks_config.cluster_name

location = var.aks_config.location

}

Each environment passes a different object in its terraform.tfvars, making the configuration cleaner and easier to maintain.

Interview Answer (Recommended)

"In our project, we maintained a single reusable AKS module and separate environment folders for Dev, QA, and Production. The module contained the common AKS configuration, while each environment had its own terraform.tfvars file with values such as cluster name, node count, VM size, autoscaling limits, tags, and resource group. Our Azure DevOps pipeline selected the appropriate tfvars file based on the target environment. This allowed us to reuse the same code while provisioning different-sized AKS clusters with environment-specific configurations, reducing duplication and ensuring consistency across environments."

This is the architecture most enterprises follow because it is scalable, maintainable, and aligns well with CI/CD practices.
