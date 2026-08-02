# Part 3 – AKS Module

> **Note:** This is an interview-ready enterprise version. Some optional settings (maintenance windows, Defender, workload identity, etc.) are omitted for readability but can be added later.

## Folder Structure

```
modules/
   └── aks/
          main.tf
          variables.tf
          outputs.tf
```

---

## main.tf

### Get Current Client

```hcl
data "azurerm_client_config" "current" {}
```

### AKS Cluster

```hcl
resource "azurerm_kubernetes_cluster" "aks" {

  name                = var.cluster_name

  location            = var.location

  resource_group_name = var.resource_group_name

  dns_prefix          = "aks"

  kubernetes_version  = var.kubernetes_version

  private_cluster_enabled = true

  sku_tier = "Standard"

  automatic_upgrade_channel = "patch"

  image_cleaner_enabled = true

  image_cleaner_interval_hours = 48

  node_resource_group = "${var.resource_group_name}-node-rg"

  default_node_pool {

      name = "system"

      vm_size = "Standard_DS3_v2"

      vnet_subnet_id = var.aks_subnet_id

      zones = [
          "1",
          "2",
          "3"
      ]

      only_critical_addons_enabled = true

      enable_auto_scaling = true

      min_count = 2

      max_count = 5

      os_disk_size_gb = 128

      type = "VirtualMachineScaleSets"

  }

  identity {

      type = "SystemAssigned"

  }

  network_profile {

      network_plugin = "azure"

      network_policy = "azure"

      outbound_type = "userDefinedRouting"

      load_balancer_sku = "standard"

      dns_service_ip = "10.2.0.10"

      service_cidr = "10.2.0.0/16"

  }

  oms_agent {

      log_analytics_workspace_id =
      var.log_analytics_workspace_id

  }

  azure_policy_enabled = true

  tags = var.tags

}
```

### User Node Pool

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "userpool" {

  name = "userpool"

  kubernetes_cluster_id =
  azurerm_kubernetes_cluster.aks.id

  vm_size = "Standard_DS3_v2"

  mode = "User"

  node_count = 2

  vnet_subnet_id = var.aks_subnet_id

  zones = [
      "1",
      "2",
      "3"
  ]

  enable_auto_scaling = true

  min_count = 2

  max_count = 10

  os_disk_size_gb = 128

}
```

### AKS to ACR

```hcl
resource "azurerm_role_assignment" "acr_pull" {

  scope = var.acr_id

  role_definition_name = "AcrPull"

  principal_id =
  azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

}
```

### Key Vault Secrets User

```hcl
resource "azurerm_role_assignment" "kv" {

  scope = var.keyvault_id

  role_definition_name = "Key Vault Secrets User"

  principal_id =
  azurerm_kubernetes_cluster.aks.identity[0].principal_id

}
```

### Monitoring Metrics Publisher

```hcl
resource "azurerm_role_assignment" "monitor" {

  scope = azurerm_kubernetes_cluster.aks.id

  role_definition_name = "Monitoring Metrics Publisher"

  principal_id =
  azurerm_kubernetes_cluster.aks.identity[0].principal_id

}
```

### Diagnostic Settings

```hcl
resource "azurerm_monitor_diagnostic_setting" "aks" {

  name = "aks-diagnostics"

  target_resource_id =
  azurerm_kubernetes_cluster.aks.id

  log_analytics_workspace_id =
  var.log_analytics_workspace_id

  enabled_log {

      category = "kube-apiserver"

  }

  enabled_log {

      category = "kube-audit"

  }

  enabled_log {

      category = "kube-controller-manager"

  }

  enabled_log {

      category = "cluster-autoscaler"

  }

  enabled_log {

      category = "guard"

  }

  metric {

      category = "AllMetrics"

  }

}
```

### Azure Monitor Alert

```hcl
resource "azurerm_monitor_metric_alert" "cpu" {

  name = "AKS-CPU"

  resource_group_name =
  var.resource_group_name

  scopes = [
      azurerm_kubernetes_cluster.aks.id
  ]

  criteria {

      metric_namespace =
      "Microsoft.ContainerService/managedClusters"

      metric_name = "node_cpu_usage_percentage"

      aggregation = "Average"

      operator = "GreaterThan"

      threshold = 80

  }

  action {

      action_group_id =
      var.action_group_id

  }

}
```

---

## variables.tf

```hcl
variable "cluster_name" {}

variable "resource_group_name" {}

variable "location" {}

variable "kubernetes_version" {}

variable "aks_subnet_id" {}

variable "log_analytics_workspace_id" {}

variable "acr_id" {}

variable "keyvault_id" {}

variable "action_group_id" {}

variable "tags" {

  type = map(string)

}
```

---

## outputs.tf

```hcl
output "aks_id" {

  value =
  azurerm_kubernetes_cluster.aks.id

}

output "aks_name" {

  value =
  azurerm_kubernetes_cluster.aks.name

}

output "kubelet_identity" {

  value =
  azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

}

output "principal_id" {

  value =
  azurerm_kubernetes_cluster.aks.identity[0].principal_id

}
```

---

## terraform.tfvars

```hcl
cluster_name = "aks-prod"

kubernetes_version = "1.31"

location = "Central India"
```

---

## End-to-End Flow

```
Azure DevOps
     │
     ▼
Self Hosted Agent
     │
     ▼
Private AKS API
     │
     ▼
AKS
     │
     ▼
System Node Pool
     │
     ▼
User Node Pool
     │
     ▼
Pods
     │
     ▼
Private Endpoint
     │
     ▼
Key Vault
     │
     ▼
ACR
     │
     ▼
Storage
```
