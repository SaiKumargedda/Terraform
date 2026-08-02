# Azure Front Door Module

This is one of the most commonly asked Azure interview topics because it sits before Application Gateway.

## Folder Structure

```
modules/
   └── frontdoor/
          main.tf
          variables.tf
          outputs.tf
```

---

## 1. Front Door Profile

```hcl
resource "azurerm_cdn_frontdoor_profile" "fd" {

  name                = var.frontdoor_name

  resource_group_name = var.resource_group_name

  sku_name            = "Premium_AzureFrontDoor"

  tags = var.tags

}
```

---

## 2. Front Door Endpoint

```hcl
resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {

  name = "frontend"

  cdn_frontdoor_profile_id =
  azurerm_cdn_frontdoor_profile.fd.id

}
```

Azure creates:

```
frontend.azurefd.net
```

---

## 3. Origin Group

```hcl
resource "azurerm_cdn_frontdoor_origin_group" "origin_group" {

  name = "aks-origin-group"

  cdn_frontdoor_profile_id =
  azurerm_cdn_frontdoor_profile.fd.id

  session_affinity_enabled = false

  load_balancing {

      sample_size = 4

      successful_samples_required = 3

  }

  health_probe {

      interval_in_seconds = 120

      path = "/health"

      protocol = "Https"

      request_type = "GET"

  }

}
```

---

## 4. Origin (Central India)

```hcl
resource "azurerm_cdn_frontdoor_origin" "central" {

  name = "central-india"

  cdn_frontdoor_origin_group_id =
  azurerm_cdn_frontdoor_origin_group.origin_group.id

  host_name = var.central_appgw_fqdn

  http_port = 80

  https_port = 443

  enabled = true

  priority = 1

  weight = 1000

}
```

---

## 5. Origin (South India)

```hcl
resource "azurerm_cdn_frontdoor_origin" "south" {

  name = "south-india"

  cdn_frontdoor_origin_group_id =
  azurerm_cdn_frontdoor_origin_group.origin_group.id

  host_name = var.south_appgw_fqdn

  http_port = 80

  https_port = 443

  enabled = true

  priority = 2

  weight = 1000

}
```

---

## 6. Route

```hcl
resource "azurerm_cdn_frontdoor_route" "default" {

  name = "default-route"

  cdn_frontdoor_endpoint_id =
  azurerm_cdn_frontdoor_endpoint.endpoint.id

  cdn_frontdoor_origin_group_id =
  azurerm_cdn_frontdoor_origin_group.origin_group.id

  patterns_to_match = [
      "/*"
  ]

  supported_protocols = [
      "Http",
      "Https"
  ]

  forwarding_protocol = "HttpsOnly"

  https_redirect_enabled = true

  link_to_default_domain = true

}
```

---

## 7. Front Door WAF

```hcl
resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {

  name = "frontdoor-waf"

  resource_group_name = var.resource_group_name

  sku_name = "Premium_AzureFrontDoor"

  enabled = true

  mode = "Prevention"

  managed_rule {

      type = "DefaultRuleSet"

      version = "2.1"

  }

}
```

---

## 8. Security Policy

```hcl
resource "azurerm_cdn_frontdoor_security_policy" "security" {

  name = "security-policy"

  cdn_frontdoor_profile_id =
  azurerm_cdn_frontdoor_profile.fd.id

  security_policies {

      firewall {

          cdn_frontdoor_firewall_policy_id =
          azurerm_cdn_frontdoor_firewall_policy.waf.id

          association {

              patterns_to_match = [
                  "/*"
              ]

              domain {

                  cdn_frontdoor_domain_id =
                  azurerm_cdn_frontdoor_endpoint.endpoint.id

              }

          }

      }

  }

}
```

---

## 9. Custom Domain

```hcl
resource "azurerm_cdn_frontdoor_custom_domain" "domain" {

  name = "company"

  cdn_frontdoor_profile_id =
  azurerm_cdn_frontdoor_profile.fd.id

  host_name = "www.company.com"

  tls {

      certificate_type = "ManagedCertificate"

  }

}
```

---

## 10. Diagnostic Settings

```hcl
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {

  name = "frontdoor-diagnostics"

  target_resource_id =
  azurerm_cdn_frontdoor_profile.fd.id

  log_analytics_workspace_id =
  var.loganalytics_id

  enabled_log {

      category = "FrontDoorAccessLog"

  }

  enabled_log {

      category = "FrontDoorHealthProbeLog"

  }

  enabled_log {

      category = "FrontDoorWebApplicationFirewallLog"

  }

  metric {

      category = "AllMetrics"

  }

}
```

---

## variables.tf

```hcl
variable "frontdoor_name" {}

variable "resource_group_name" {}

variable "loganalytics_id" {}

variable "central_appgw_fqdn" {}

variable "south_appgw_fqdn" {}

variable "tags" {

  type = map(string)

}
```

---

## outputs.tf

```hcl
output "frontdoor_endpoint" {

  value =
  azurerm_cdn_frontdoor_endpoint.endpoint.host_name

}

output "frontdoor_profile_id" {

  value =
  azurerm_cdn_frontdoor_profile.fd.id

}
```

---

## End-to-End Flow

```
User
     │
     ▼
www.company.com
     │
     ▼
Azure DNS
     │
     ▼
CNAME
     │
     ▼
frontend.azurefd.net
     │
     ▼
Azure Front Door
     │
     ▼
WAF
     │
     ▼
Route
     │
     ▼
Origin Group
     │
     ▼
Health Probe
     │
     ▼
Central India App Gateway (Priority 1)
     │
     ▼
AKS
     │
     ▼
Pods
```

**If Central India fails:**

```
Health Probe Failed
     │
     ▼
Origin Unhealthy
     │
     ▼
South India App Gateway (Priority 2)
     │
     ▼
AKS
     │
     ▼
Pods
```

---

## Interview Questions

**Why do we create an Origin Group?**

It groups one or more backend origins so Front Door can perform health checks, load balancing, and failover.

**Why do we assign different priorities?**

Priority enables active-passive failover. A lower priority number is preferred. If the primary origin is unhealthy, Front Door automatically switches to the next healthy origin.

**Why use weights?**

Weights distribute traffic between healthy origins. For example:

```
Origin A: weight = 900
Origin B: weight = 100
```

Approximately 90% of requests go to Origin A and 10% to Origin B.

**Why point Front Door to the Application Gateway FQDN instead of AKS?**

Application Gateway is the ingress layer that handles TLS termination, routing, WAF (if enabled), and forwards requests to Kubernetes services. Front Door should target the Application Gateway endpoint rather than individual AKS nodes or pods.
