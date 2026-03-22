trigger:
- main

variables:
  TF_VERSION: '1.5.0'
  SERVICE_CONNECTION: 'sc-wif-terraform'

stages:

# 🔷 STAGE 1: VALIDATE
- stage: Validate
  jobs:
  - job: Validate
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: self

    - task: TerraformInstaller@1
      inputs:
        terraformVersion: $(TF_VERSION)

    - script: |
        terraform --version
        terraform init -backend=false
        terraform validate
      displayName: "Terraform Validate"

# 🔷 STAGE 2: PLAN (DEV)
- stage: Dev_Plan
  dependsOn: Validate
  jobs:
  - job: Plan
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: self

    - task: TerraformInstaller@1
      inputs:
        terraformVersion: $(TF_VERSION)

    - task: AzureCLI@2
      inputs:
        azureSubscription: $(SERVICE_CONNECTION)
        scriptType: bash
        scriptLocation: inlineScript
        inlineScript: |
          cd envs/dev
          terraform init
          terraform plan -var-file="terraform.tfvars" -out=tfplan

# 🔷 STAGE 3: APPLY (DEV)
- stage: Dev_Apply
  dependsOn: Dev_Plan
  jobs:
  - job: Apply
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: self

    - task: AzureCLI@2
      inputs:
        azureSubscription: $(SERVICE_CONNECTION)
        scriptType: bash
        scriptLocation: inlineScript
        inlineScript: |
          cd envs/dev
          terraform init
          terraform apply -auto-approve

# 🔷 STAGE 4: PLAN (PROD)
- stage: Prod_Plan
  dependsOn: Dev_Apply
  jobs:
  - job: Plan
    steps:
    - checkout: self

    - task: AzureCLI@2
      inputs:
        azureSubscription: $(SERVICE_CONNECTION)
        scriptType: bash
        scriptLocation: inlineScript
        inlineScript: |
          cd envs/prod
          terraform init
          terraform plan -var-file="terraform.tfvars" -out=tfplan

# 🔥 APPROVAL GATE HERE (Environment in Azure DevOps)

# 🔷 STAGE 5: APPLY (PROD)
- stage: Prod_Apply
  dependsOn: Prod_Plan
  jobs:
  - job: Apply
    steps:
    - checkout: self

    - task: AzureCLI@2
      inputs:
        azureSubscription: $(SERVICE_CONNECTION)
        scriptType: bash
        scriptLocation: inlineScript
        inlineScript: |
          cd envs/prod
          terraform init
          terraform apply tfplan
