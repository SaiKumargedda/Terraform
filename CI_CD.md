# README-14-Terraform-Infrastructure-Pipeline.md

# Terraform Infrastructure Pipeline using Azure DevOps

---

# 1. Overview

Terraform pipelines are used to provision and manage Azure infrastructure in a repeatable and consistent manner.

Resources managed:

* Resource Groups
* VNETs
* Subnets
* NSGs
* AKS
* ACR
* Key Vault
* Storage Accounts
* Log Analytics Workspace
* Application Gateway
* Managed Identities

---

# 2. Architecture

Developer

↓

Terraform Repo

↓

PR Validation

↓

Terraform fmt

↓

Terraform Validate

↓

Checkov Scan

↓

Terraform Plan

↓

Publish Plan Artifact

↓

Approval

↓

Terraform Apply

↓

Azure Resources

---

# 3. Repository Structure

```text
terraform-infra

├── modules

│   ├── network

│   ├── aks

│   ├── acr

│   ├── keyvault

│   ├── storage

│   └── appgateway

├── environments

│   ├── dev

│   │    main.tf
│   │    variables.tf
│   │    terraform.tfvars
│   │    backend.tf

│   ├── qa

│   └── prod

└── azure-pipelines.yml
```

---

# 4. Backend Configuration

backend.tf

```hcl
terraform {

 backend "azurerm" {

  resource_group_name  = "tfstate-rg"

  storage_account_name = "tfstatesa"

  container_name       = "tfstate"

  key                  = "dev.tfstate"

 }

}
```

Benefits:

* Remote state
* State locking
* Team collaboration

---

# 5. Service Connection

Azure RM Service Connection:

```text
dev-rm-sc
```

Service Principal Role:

```text
Contributor
```

Scope:

```text
Resource Group Level
```

Preferred over Subscription level.

---

# 6. Variable Group

Contains:

```text
tf_state_rg

tf_state_sa

tf_state_container

environment

backend_key
```

---

# 7. CI Flow

```text
fmt

↓

validate

↓

Checkov

↓

terraform plan

↓

Publish tfplan
```

---

# 8. CD Flow

```text
Approval

↓

terraform apply

↓

Azure Resources Created
```

---

# 9. Complete Pipeline

```yaml
trigger:

- main

pool:
  name: VMSS-AgentPool

variables:

- group: terraform-dev

stages:

- stage: Validate

  jobs:

  - job: Validate

    steps:

    - checkout: self

    - task: TerraformInstaller@1

      inputs:

        terraformVersion: '1.9.0'

    - task: AzureCLI@2

      inputs:

        azureSubscription: dev-rm-sc

        scriptType: bash

        scriptLocation: inlineScript

        inlineScript: |

          cd environments/dev

          terraform init

          terraform fmt -check

          terraform validate

- stage: Security

  dependsOn: Validate

  jobs:

  - job: Checkov

    steps:

    - script: |

        pip install checkov

        checkov -d environments/dev

- stage: Plan

  dependsOn: Security

  jobs:

  - job: Plan

    steps:

    - task: AzureCLI@2

      inputs:

        azureSubscription: dev-rm-sc

        scriptType: bash

        scriptLocation: inlineScript

        inlineScript: |

          cd environments/dev

          terraform init

          terraform plan \
          -var-file=terraform.tfvars \
          -out=tfplan

    - task: PublishPipelineArtifact@1

      inputs:

        targetPath: environments/dev/tfplan

        artifactName: terraform-plan

- stage: Apply

  dependsOn: Plan

  jobs:

  - deployment: ApplyInfra

    environment: terraform-dev

    strategy:

      runOnce:

        deploy:

          steps:

          - download: current

            artifact: terraform-plan

          - task: AzureCLI@2

            inputs:

              azureSubscription: dev-rm-sc

              scriptType: bash

              scriptLocation: inlineScript

              inlineScript: |

                cd environments/dev

                terraform init

                terraform apply tfplan
```

---

# 10. Security Scanning

Checkov detects:

* Open NSGs
* Public Storage Accounts
* Missing Encryption
* Weak Configurations

Alternative tools:

* tfsec
* Terrascan
* Prisma Cloud

---

# 11. Plan Artifact

Never execute:

```bash
terraform apply
```

directly after:

```bash
terraform plan
```

Instead:

Publish:

```text
tfplan
```

Apply same approved plan.

Benefits:

* Prevent drift
* Governance
* Auditability

---

# 12. Environment Approvals

Dev

↓

No Approval

QA

↓

Lead Approval

Prod

↓

CAB Approval

---

# 13. Common Commands

Initialize

```bash
terraform init
```

Format

```bash
terraform fmt
```

Validate

```bash
terraform validate
```

Plan

```bash
terraform plan
```

Apply

```bash
terraform apply
```

Destroy

```bash
terraform destroy
```

Import

```bash
terraform import
```

Refresh

```bash
terraform refresh
```

---

# 14. Common Errors

State Lock

```text
Error acquiring state lock
```

Fix:

Verify blob lease.

---

Authorization Failed

Cause:

Contributor missing.

---

Resource Exists

Fix:

```bash
terraform import
```

---

Drift

Fix:

```bash
terraform plan
```

---

Version Conflict

Fix:

```bash
terraform init -upgrade
```

---

# 15. State Locking

Azure Blob Lease prevents:

```text
Two engineers executing apply simultaneously
```

Only one execution allowed.

---

# 16. State File Best Practices

Never store:

```text
terraform.tfstate
```

inside Git.

Use:

Remote backend.

Enable:

Versioning.

---

# 17. Workspaces

Useful for:

```text
dev

qa

prod
```

Example:

```bash
terraform workspace new dev

terraform workspace select dev
```

Large enterprises often prefer separate folders instead.

---

# 18. count vs for_each

count

```hcl
count = 3
```

Creates:

```text
vm0

vm1

vm2
```

for_each

```hcl
for_each = {
 dev="Standard_B2s"
 qa="Standard_D2s"
}
```

Preferred.

---

# 19. Lifecycle Block

```hcl
lifecycle {

 prevent_destroy = true

 ignore_changes = [
 tags
 ]

}
```

Useful for:

AKS

Storage Accounts

---

# 20. depends_on

```hcl
depends_on = [

azurerm_virtual_network.vnet

]
```

Controls resource order.

---

# 21. Dynamic Blocks

Useful for:

NSG rules

Subnets

Disks

---

# 22. Improvements Implemented

✔ Modular Structure

✔ Remote Backend

✔ Blob Locking

✔ Checkov Security Scan

✔ Plan Artifact Publishing

✔ Environment Approvals

✔ Reusable Modules

✔ Self Hosted Agents

✔ YAML Templates

---

# 23. Interview Questions

Q. Why remote backend?

Answer:

To enable collaboration and state locking.

---

Q. Why publish tfplan artifact?

Answer:

Apply should execute the same reviewed plan, improving consistency and governance.

---

Q. Why not apply directly after plan?

Answer:

Plan and Apply are separated to allow approvals and avoid unexpected changes.

---

Q. How did you manage multiple environments?

Answer:

Using separate environment folders and tfvars files.

---

Q. How did you prevent concurrent execution?

Answer:

Blob lease locking and environment approvals.

---

Q. How did you secure Terraform?

Answer:

Checkov scan, remote backend, least privilege RBAC, Key Vault integration and approvals.

---

Q. What challenges did you face?

Answer:

State lock, drift, authorization failures and existing resource conflicts.

---

# Real Project Flow

Terraform Repo

↓

PR Validation

↓

fmt

↓

validate

↓

Checkov

↓

plan

↓

Publish tfplan

↓

Approval

↓

Apply

↓

Azure Infrastructure

↓

AKS

↓

ACR

↓

Key Vault

↓

Application Deployment Pipelines
