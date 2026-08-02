# Part 4.1 – Application Gateway

This is a production-style configuration based on the current AzureRM provider structure.

## Public IP

```hcl
resource "azurerm_public_ip" "appgw" {

  name                = "pip-appgw"

  location            = var.location

  resource_group_name = var.resource_group_name

  allocation_method   = "Static"

  sku                 = "Standard"

  zones = [
    "1",
    "2",
    "3"
  ]

  tags = var.tags
}
```

---

## WAF Policy

```hcl
resource "azurerm_web_application_firewall_policy" "waf" {

  name                = "waf-policy"

  location            = var.location

  resource_group_name = var.resource_group_name

  policy_settings {

    enabled = true

    mode = "Prevention"

    request_body_check = true

    file_upload_limit_in_mb = 100

    max_request_body_size_in_kb = 128

  }

  managed_rules {

    managed_rule_set {

      type = "OWASP"

      version = "3.2"

    }

  }

}
```

---

## Application Gateway

```hcl
resource "azurerm_application_gateway" "appgw" {

  name                = var.appgw_name

  location            = var.location

  resource_group_name = var.resource_group_name

  firewall_policy_id  = azurerm_web_application_firewall_policy.waf.id

  zones = [
      "1",
      "2",
      "3"
  ]

  sku {

      name = "WAF_v2"

      tier = "WAF_v2"

      capacity = 2

  }

  gateway_ip_configuration {

      name = "gateway-ip-config"

      subnet_id = var.appgw_subnet_id

  }

  frontend_ip_configuration {

      name = "frontend-ip"

      public_ip_address_id =
      azurerm_public_ip.appgw.id

  }

  frontend_port {

      name = "http"

      port = 80

  }

  frontend_port {

      name = "https"

      port = 443

  }

  backend_address_pool {

      name = "aks-backend"

  }

  backend_http_settings {

      name = "backend-setting"

      cookie_based_affinity = "Disabled"

      port = 80

      protocol = "Http"

      request_timeout = 30

      probe_name = "aks-health"

  }

  probe {

      name = "aks-health"

      protocol = "Http"

      path = "/health"

      interval = 30

      timeout = 30

      unhealthy_threshold = 3

      pick_host_name_from_backend_http_settings = true

      match {

          status_code = [
            "200-399"
          ]

      }

  }

}
```

---

## Diagnostic Settings

```hcl
resource "azurerm_monitor_diagnostic_setting" "appgw" {

  name = "appgw-diagnostics"

  target_resource_id =
  azurerm_application_gateway.appgw.id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category = "ApplicationGatewayAccessLog"

  }

  enabled_log {

      category = "ApplicationGatewayPerformanceLog"

  }

  enabled_log {

      category = "ApplicationGatewayFirewallLog"

  }

  metric {

      category = "AllMetrics"

  }

}
```

---

## variables.tf

```hcl
variable "appgw_name" {}

variable "resource_group_name" {}

variable "location" {}

variable "appgw_subnet_id" {}

variable "loganalytics_id" {}

variable "tags" {

  type = map(string)

}
```

---

## outputs.tf

```hcl
output "application_gateway_id" {

  value =
  azurerm_application_gateway.appgw.id

}

output "application_gateway_public_ip" {

  value =
  azurerm_public_ip.appgw.ip_address

}
```

---

## Interview Questions

**Why do we create a dedicated subnet for Application Gateway?**

Application Gateway must be deployed in its own dedicated subnet. You cannot deploy VMs, AKS nodes, or other resources into that subnet. This is an Azure requirement.

**Why don't we add backend IPs in Terraform?**

Because AGIC (Application Gateway Ingress Controller) manages the backend pool automatically.

Flow:

```
Ingress YAML
     │
     ▼
AGIC
     │
     ▼
Application Gateway Backend Pool
     │
     ▼
AKS Service
     │
     ▼
Pods
```

You don't manually maintain backend addresses when using AGIC.

**Why is the backend pool empty?**

This is expected in an AGIC architecture.

Initially:

```
Backend Pool
     │
     ▼
Empty
```

After deployment:

```
Backend Pool
     │
     ▼
Pod IPs
     │
     ▼
AKS Services
```

AGIC watches Kubernetes Ingress resources and updates the Application Gateway configuration dynamically.

---
---

# Part 4.2 – Application Gateway (Listeners, SSL, Routing & AGIC)

## SSL Certificate

If you're storing the PFX certificate in Key Vault, you typically retrieve it and configure the Application Gateway to use it.

```hcl
data "azurerm_key_vault_secret" "ssl" {

  name         = "ssl-cert"

  key_vault_id = var.keyvault_id

}
```

```hcl
ssl_certificate {

  name = "ssl-cert"

  data     = data.azurerm_key_vault_secret.ssl.value

  password = var.ssl_password

}
```

---

## HTTP Listener

```hcl
http_listener {

  name = "http-listener"

  frontend_ip_configuration_name = "frontend-ip"

  frontend_port_name = "http"

  protocol = "Http"

}
```

## HTTPS Listener

```hcl
http_listener {

  name = "https-listener"

  frontend_ip_configuration_name = "frontend-ip"

  frontend_port_name = "https"

  protocol = "Https"

  ssl_certificate_name = "ssl-cert"

}
```

---

## Redirect HTTP → HTTPS

```hcl
redirect_configuration {

  name = "http-redirect"

  redirect_type = "Permanent"

  target_listener_name = "https-listener"

  include_path = true

  include_query_string = true

}
```

---

## HTTP Routing Rule

```hcl
request_routing_rule {

  name = "http-rule"

  priority = 100

  rule_type = "Basic"

  http_listener_name = "http-listener"

  redirect_configuration_name = "http-redirect"

}
```

## HTTPS Routing Rule

```hcl
request_routing_rule {

  name = "https-rule"

  priority = 200

  rule_type = "Basic"

  http_listener_name = "https-listener"

  backend_address_pool_name = "aks-backend"

  backend_http_settings_name = "backend-setting"

}
```

---

## URL Path Map

```hcl
url_path_map {

  name = "application-paths"

  default_backend_address_pool_name = "aks-backend"

  default_backend_http_settings_name = "backend-setting"

  path_rule {

      name = "api"

      paths = [
        "/api/*"
      ]

      backend_address_pool_name = "aks-backend"

      backend_http_settings_name = "backend-setting"

  }

  path_rule {

      name = "web"

      paths = [
        "/web/*"
      ]

      backend_address_pool_name = "aks-backend"

      backend_http_settings_name = "backend-setting"

  }

}
```

---

## Path-Based Routing Rule

```hcl
request_routing_rule {

  name = "path-routing"

  priority = 300

  rule_type = "PathBasedRouting"

  http_listener_name = "https-listener"

  url_path_map_name = "application-paths"

}
```

---

## Rewrite Rule Set

```hcl
rewrite_rule_set {

  name = "rewrite"

  rewrite_rule {

      name = "security-header"

      rule_sequence = 100

      response_header_configuration {

          header_name = "X-Frame-Options"

          header_value = "DENY"

      }

  }

}
```

## Associate Rewrite Rule

```hcl
request_routing_rule {

  name = "rewrite-rule"

  priority = 400

  rule_type = "Basic"

  http_listener_name = "https-listener"

  backend_address_pool_name = "aks-backend"

  backend_http_settings_name = "backend-setting"

  rewrite_rule_set_name = "rewrite"

}
```

---

## AGIC Add-on in AKS

Instead of manually configuring backend pools, enable AGIC in AKS.

```hcl
ingress_application_gateway {

  gateway_id = var.application_gateway_id

}
```

> This block belongs inside the AKS resource, not the Application Gateway resource.

---

## Role Assignment for AGIC

```hcl
resource "azurerm_role_assignment" "agic" {

  scope = var.application_gateway_id

  role_definition_name = "Contributor"

  principal_id =
  azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id

}
```

---

## Variables

```hcl
variable "application_gateway_id" {}

variable "keyvault_id" {}

variable "ssl_password" {
  sensitive = true
}
```

---

## Complete Flow

```
Internet User
      │
      ▼
Azure Front Door
      │
      ▼
Application Gateway
      │
      ├──────── HTTP Listener
      │
      ├──────── HTTPS Listener
      │
      ├──────── Redirect HTTP → HTTPS
      │
      ├──────── Routing Rule
      │
      ├──────── URL Path Map
      │
      ├──────── Rewrite Rules
      │
      ▼
Backend Pool (Managed by AGIC)
      │
      ▼
AKS Service
      │
      ▼
Pods
```

---

## Interview Questions

**Why is the backend pool empty in Terraform?**

Because AGIC dynamically populates it from Kubernetes Ingress resources. We don't manually add pod IPs.

**Why do we use URL Path Maps?**

To route different paths to different applications, for example:

- `/api/*` → API service
- `/web/*` → Frontend service
- `/admin/*` → Admin service

**Why use Rewrite Rules?**

To modify request or response headers without changing the application. Common examples include adding security headers or rewriting URLs.

**Why do we redirect HTTP to HTTPS?**

To ensure all traffic is encrypted and to prevent users from accessing the application over insecure HTTP.
