# Azure AKS Multi-Region Terraform Platform

This Terraform project deploys:

- Azure Kubernetes Service (AKS)
- Azure Container Registry (ACR)
- Azure Key Vault
- Modular Terraform structure
- Environment configs (dev/stage/prod)

Architecture:

Internet
 |
Azure Front Door
 |
Application Gateway
 |
AKS
 |
Pods