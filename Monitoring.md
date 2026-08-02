# Part 8 – Monitoring Module

## Folder Structure

```
modules/
    monitoring/
        main.tf
        variables.tf
        outputs.tf
```

---

## 1. Action Group

```hcl
resource "azurerm_monitor_action_group" "devops" {

  name                = "DevOps-ActionGroup"

  resource_group_name = var.resource_group_name

  short_name          = "DevOps"

  email_receiver {

      name          = "DevOps"

      email_address = var.email

  }

}
```

---

## 2. AKS CPU Alert

```hcl
resource "azurerm_monitor_metric_alert" "aks_cpu" {

  name                = "AKS-CPU"

  resource_group_name = var.resource_group_name

  scopes = [
      var.aks_id
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
      azurerm_monitor_action_group.devops.id

  }

}
```

---

## 3. AKS Memory Alert

```hcl
resource "azurerm_monitor_metric_alert" "aks_memory" {

  name = "AKS-Memory"

  resource_group_name =
  var.resource_group_name

  scopes = [
      var.aks_id
  ]

  criteria {

      metric_namespace =
      "Microsoft.ContainerService/managedClusters"

      metric_name =
      "node_memory_working_set_percentage"

      aggregation = "Average"

      operator = "GreaterThan"

      threshold = 80

  }

  action {

      action_group_id =
      azurerm_monitor_action_group.devops.id

  }

}
```

---

## 4. Application Gateway Diagnostics

```hcl
resource "azurerm_monitor_diagnostic_setting" "appgw" {

  name = "appgw"

  target_resource_id =
  var.application_gateway_id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category =
      "ApplicationGatewayAccessLog"

  }

  enabled_log {

      category =
      "ApplicationGatewayPerformanceLog"

  }

  enabled_log {

      category =
      "ApplicationGatewayFirewallLog"

  }

  metric {

      category = "AllMetrics"

  }

}
```

---

## 5. Azure Firewall Diagnostics

```hcl
resource "azurerm_monitor_diagnostic_setting" "firewall" {

  name = "firewall"

  target_resource_id =
  var.firewall_id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category =
      "AzureFirewallApplicationRule"

  }

  enabled_log {

      category =
      "AzureFirewallNetworkRule"

  }

  enabled_log {

      category =
      "AzureFirewallDnsProxy"

  }

  metric {

      category = "AllMetrics"

  }

}
```

---

## 6. Front Door Diagnostics

```hcl
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {

  name = "frontdoor"

  target_resource_id =
  var.frontdoor_id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category =
      "FrontDoorAccessLog"

  }

  enabled_log {

      category =
      "FrontDoorHealthProbeLog"

  }

  enabled_log {

      category =
      "FrontDoorWebApplicationFirewallLog"

  }

}
```

---

## 7. Key Vault Diagnostics

```hcl
resource "azurerm_monitor_diagnostic_setting" "keyvault" {

  name = "keyvault"

  target_resource_id =
  var.keyvault_id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category = "AuditEvent"

  }

}
```

---

## 8. ACR Diagnostics

```hcl
resource "azurerm_monitor_diagnostic_setting" "acr" {

  name = "acr"

  target_resource_id =
  var.acr_id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category =
      "ContainerRegistryRepositoryEvents"

  }

  enabled_log {

      category =
      "ContainerRegistryLoginEvents"

  }

}
```

---

## 9. Storage Diagnostics

```hcl
resource "azurerm_monitor_diagnostic_setting" "storage" {

  name = "storage"

  target_resource_id =
  var.storage_account_id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category = "StorageRead"

  }

  enabled_log {

      category = "StorageWrite"

  }

  enabled_log {

      category = "StorageDelete"

  }

}
```

---

## 10. Action Group for Webhook (Optional)

```hcl
webhook_receiver {

    name = "Teams"

    service_uri = var.logicapp_url

}
```

---

## variables.tf

```hcl
variable "resource_group_name" {}

variable "email" {}

variable "aks_id" {}

variable "acr_id" {}

variable "keyvault_id" {}

variable "storage_account_id" {}

variable "firewall_id" {}

variable "application_gateway_id" {}

variable "frontdoor_id" {}

variable "loganalytics_id" {}

variable "logicapp_url" {}
```

---

## outputs.tf

```hcl
output "action_group_id" {

  value =
  azurerm_monitor_action_group.devops.id

}
```

---

## Enterprise Monitoring Flow

```
AKS
 │
 ├────────► Log Analytics
 │
 ├────────► Container Insights
 │
 ├────────► Azure Monitor
 │
 ├────────► Metric Alerts
 │
 └────────► Action Group
                     │
                     ├────────► Email
                     ├────────► SMS
                     ├────────► Webhook
                     ├────────► Logic App
                     └────────► Azure Function
```

---

## Complete Enterprise Architecture

```
User
 │
 ▼
Azure DNS
 │
 ▼
Azure Front Door
 │
 ▼
Application Gateway (WAF)
 │
 ▼
AKS Private Cluster
 │
 ▼
Pods
 │
 ├────────► Key Vault (Private Endpoint)
 ├────────► ACR (Private Endpoint)
 ├────────► Storage (Private Endpoint)
 └────────► SQL (Private Endpoint)
```

### Networking

```
VNet
 ├── AKS Subnet
 ├── App Gateway Subnet
 ├── Azure Firewall Subnet
 └── Private Endpoint Subnet
```

### Security

- NSG
- UDR
- Azure Firewall
- Firewall Policy

### Monitoring

- Azure Monitor
- Log Analytics
- Application Insights
- Diagnostic Settings
- Action Groups
- Alerts
