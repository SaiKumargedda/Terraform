## resource group

provider "azurerm"
{
  features{}
  
}

resource "azurerm_resource_group" "rg"
{

  name="rg_dev"
  location="central india"
  
lifecycle{

prevent_destroy= true

}
  
  tags=
  {
        
		env="dev"
		project="aks-demo"
	}
  
}

---------------------------------------------------------------------

## Avoid hardcoding use variables ##

variable "rg_name"
{
  type=string
}

variable "location"
{
  type=string
  
}

resource "azurerm_resource_group" "rg"
{

 name=var.rg_name
 location=var.location
 
}
--------------------------------------------------------------------

##Azure Storage Account ##

terraform {

backend "azurerm"
{

 resource_group_name=""
 storage_account_name=""
 container_name=""
 key=""
}
}

----------------------------------------------------------------------

##terraform import "resource_group"

terraform import azurerm_resource_group.rg /subscriptions/<id>/resourceGroups/rg-name

---------------------------------------------------------------------

##virtual network ##

resource "azurerm_virtual_network" "vnet"
{

 name="vnet_dev"
 location="cental_india"
 resource_group_name=azurerm_resource_group.rg.name
 address_space=["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_app"
{
  name= "subnet_app"
  resource_group_name= azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  adress_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_subnet" subnet_db"
{
  name="subnet_db"
  resource_group_name= azurerm_resource_group.rg.name
  virtual_network_name=azurerm_virtual_network.vnet.name
  address_prefix=["10.0.2.0/24"]
}

-----------------------------------------------------------------------------

##vnet peering##

resource "azurerm_virtual_netowrk_peering" "peer"
{
  name= "vnet_peer"
  resource_group_name= azurerm_resource_group.rg.name
  virtual_network_name=azurerm_virtual_network.vm=net.name
  remote_virtual_netowrk_id "<remote_vnet_id>"
}

-----------------------------------------------------------------------------

##NSG##

resource "azurerm_network_security_group" "nsg"
{
  name=""
  location=""
  resource_group_name= azurerm_resourcr_group_name.rg.name
}

resource "network_security_rule" "allow_ssh"

{

  name="allow_ssh"
  priority="100"  //100-4096 (lowest no = highest priority//
  direction="Inbound"
  access="Allow"
  protocol="TCP"
  
  source_port_range="*"
  destination_port_range="22"
  
  source_address_prefix=""
  destination_adress_prefix=""
  
  resource_group_name=azurerm_resource_group.rg.name
  resource_netowrk_security_group=azurerm_network_security_group.nsg.name
  
}

resource "azurerm_subnet_netowrk_security_group_association" "nsg_assoc "
{
  subnet_id= azurerm_subnet.subnet_app.id
  network_security_group_id=azurerm_netowork_security_group.nsg.id
}

-----------------------------------------------------------------------------

##ASG##

resource "azurerm_application_security_group" "asg" {
  name                = "asg-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_http_asg" {
  name                        = "allow-http"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"

  source_port_range          = "*"
  destination_port_range     = "80"

  source_address_prefix      = "*"

  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name

  destination_application_security_group_ids = [
    azurerm_application_security_group.asg.id
  ]
}

##Attaching VM/NIC with ASG##

resource "azurerm_network_interface" "nic" {
  name                = "nic-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_app.id
    private_ip_address_allocation = "Dynamic"

    application_security_group_ids = [
      azurerm_application_security_group.asg.id
    ]
  }
}

“I group VMs using ASG by attaching their NICs. Then I apply NSG rules to ASG instead of IPs, which makes it scalable and easier to manage.”
--------------------------------------------------------------------

## Linux VM##

resource "azurerm_network_interface" "nic" {
  name                = "nic-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_app.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username = "azureuser"

  admin_ssh_key {
  username   = "azureuser"
  public_key = file("~/.ssh/id_rsa.pub")
  }

  disable_password_authentication = true
    network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

###assigning public ip##

resource "azurerm_public_ip" "pip" {
  name                = "vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# attach in NIC
public_ip_address_id = azurerm_public_ip.pip.id

----------------------------------------------------------------------------------

##ACR##

resource "azurerm_container_registry" "acr" {
  name                = "acr123demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku           = "Standard"
  admin_enabled = false

  tags = {
    environment = "dev"
  }
}

-------------------------------------------------------------------------

##AKS##

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aksdemo"

  default_node_pool {
    name       = "nodepool1"
    vm_size    = "Standard_DS2_v2"
	enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
  }

  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
  network_plugin = "azure"
  }
  
  role_based_access_control_enabled = true
  
  tags = {
    environment = "dev"
  }
}

---------------------------------------------------------------------
##Giving acr pull role to aks to pull images from acr

resource "azurerm_role_assignment" "aks_acr" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

----------------------------------------------------------------------

##user node pool for application workloads and system node pools for k8 core components

resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  name                  = "userpool1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_DS2_v2"

  node_count = 2

  mode = "User"

  orchestrator_version = azurerm_kubernetes_cluster.aks.kubernetes_version
}

-------------------------------------------------------------------------

##Networking##

##Load balancer## (L4 -TCP/UDP)

resource "azurerm_public_ip" "pip" {
  name                = "lb-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_lb" "lb" {
  name                = "lb-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
  resource "azurerm_lb_backend_address_pool" "backend" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
  }
}

“I’m creating a Public IP and associating it with a Load Balancer frontend configuration to expose services externally.”

“It is a Layer 4 load balancer that distributes traffic based on IP and port across backend resources.”

##“In production, I use Load Balancer for internal traffic and Application Gateway for HTTP/HTTPS routing with WAF.”##

---------------------------------------------------------------------------
H
##App Gateway (L7 -HTTP/HTTPS)

resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet_app.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  ssl_certificate {
  name     = "ssl-cert"
  data     = filebase64("cert.pfx")
  password = "password"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    http_listener_name         = "listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }
}


##“I’m creating an Application Gateway with WAF_v2 SKU for L7 routing.
It listens on HTTP, routes traffic to backend pool, and supports advanced features like SSL termination and WAF protection.”

--------------------------------------------------------------------

##NAT GATEWAY##

resource "azurerm_public_ip" "nat_pip" {
  name                = "nat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name                = "nat-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_nat" {
  subnet_id      = azurerm_subnet.subnet_app.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

##“I’m creating a NAT Gateway and associating it with a subnet to provide controlled outbound internet access with a static public IP.”

----------------------------------------------------------------

Route Tables (UDR – User Defined Routing)


resource "azurerm_route_table" "rt" {
  name                = "rt-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_route" "route_internet" {
  name                   = "route-to-internet"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "Internet"
}

resource "azurerm_subnet_route_table_association" "rt_assoc" {
  subnet_id      = azurerm_subnet.subnet_app.id
  route_table_id = azurerm_route_table.rt.id
}

##I’m creating a route table and associating it with a subnet to control how traffic is routed.
Here, I’m defining a default route (0.0.0.0/0) to send traffic to the internet.”

----------------------------------------------------------------------
Azure Firewall (Central Security Layer)

resource "azurerm_public_ip" "fw_pip" {
  name                = "fw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "az-fw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name = "AZFW_VNet"
  sku_tier = "Standard"

  ip_configuration {
    name                 = "fw-ip-config"
    subnet_id            = azurerm_subnet.azure_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}


“I’m creating Azure Firewall in a dedicated subnet (AzureFirewallSubnet) with a public IP.
It acts as a central security layer to inspect and control traffic.”

##firewall rules

resource "azurerm_firewall_network_rule_collection" "fw_rule" {
  name                = "allow-web"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-http"
    protocol              = "TCP"
    source_addresses      = ["*"]
    destination_ports     = ["80"]
    destination_addresses = ["*"]
  }
}

“Destination NAT — used to allow inbound traffic to internal resources.”

“Source NAT — used for outbound traffic translation.”

----------------------------------------------------------------------------

Private Endpoint (Private Access to Azure Services)

resource "azurerm_private_endpoint" "pe" {
  name                = "pe-storage"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_app.id

  private_service_connection {
    name                           = "pe-connection"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

“I’m creating a Private Endpoint to access the Storage Account over a private IP within the VNet instead of using public internet.”

----------------------------------------------------------------------

Azure Key Vault

resource "azurerm_key_vault" "kv" {
  name                        = "kv-demo-12345"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  sku_name = "standard"

  soft_delete_enabled      = true
  purge_protection_enabled = true

  tags = {
    environment = "dev"
  }
}

How to store a secret?

resource "azurerm_key_vault_secret" "secret" {
  name         = "db-password"
  value        = "Password123!"
  key_vault_id = azurerm_key_vault.kv.id
}

How to give access to AKS or VM?

resource "azurerm_role_assignment" "kv_access" {
  principal_id         = "<managed-identity-id>"
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.kv.id
}

----------------------------------------------------------------

Azure DNS (Public DNS)

resource "azurerm_dns_zone" "dns" {
  name                = "mydomain.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_dns_a_record" "app" {
  name                = "app"
  zone_name           = azurerm_dns_zone.dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  records = [
    azurerm_public_ip.appgw_pip.ip_address
  ]
}

“I’m creating a DNS zone and mapping a domain (app.mydomain.com) to the Application Gateway public IP using an A record.”

What is CNAME record?


“Maps one domain name to another domain name.”

✅ Example
resource "azurerm_dns_cname_record" "cname" {
  name                = "www"
  zone_name           = azurerm_dns_zone.dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = "app.mydomain.com"
}

“In production, I use Azure DNS to map custom domains to Front Door or Application Gateway and manage DNS records centrally.”

-----------------------------------------------------------------------------

Azure Front Door (Global Load Balancer)

“I’m creating Azure Front Door as a global entry point.
It routes traffic to backend (like Application Gateway or AKS) using health probes and load balancing.”

End-to-End Final Flow
User → www.app.com
     → DNS resolves (CNAME)
     → myapp.azurefd.net
     → Azure Front Door
     → App Gateway
     → AKS
     → Pod
	 
------------------------------------------------------------------------------

##Azure Storage account

Terraform Backend Configuration

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateprod"
    container_name       = "tfstate"
    key                  = "aks-prod.tfstate"
  }
}

for dev: key = "aks-dev.tfstate"

Required Azure Resources for Backend

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = "Central India"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "sttfstateprod"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

backend will be stored as bootstrap: Initial setup to create backend storage before using it. (creating storage account and container for storing tf state file)

-----------------------------------------------------------------------------------------------

##Azure Monitoring

Log Analytics Workspace (CORE 🔥)
📌 What it does
Stores logs from:
AKS
VMs
App Insights
Azure resources
Query using KQL (Kusto Query Language)

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-prod"
  location            = "Central India"
  resource_group_name = "rg-monitoring"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}


“Log Analytics Workspace acts as the central logging backend for Azure Monitor and integrates with AKS, Application Insights, and alerts.”

Application Insights (APM)
📌 What it does
Tracks:
Request rate
Response time
Failures
Dependencies (DB/API calls)

resource "azurerm_application_insights" "appi" {
  name                = "appi-prod"
  location            = "Central India"
  resource_group_name = "rg-monitoring"
  application_type    = "web"

  workspace_id = azurerm_log_analytics_workspace.law.id
}

How it works in AKS
You instrument app using:
Java agent / SDK
Sends telemetry → App Insights → LAW

We use workspace-based Application Insights for better integration and centralized logging.”

Container Insights (AKS Monitoring)
📌 What it monitors
Node CPU / Memory
Pod usage
Container logs
OOM kills
Restart count

Terraform Example (AKS Integration)

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-prod"
  location            = "Central India"
  resource_group_name = "rg-aks"
  dns_prefix          = "aksprod"

  default_node_pool {
    name       = "nodepool1"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }
}

Behind the scenes

👉 Azure installs:

AMA / OMS agent on nodes

👉 It sends:

Metrics
Logs
→ to Log Analytics Workspace


## Alert Setup Flow
Metric / Logs
     ↓
Azure Monitor
     ↓
Alert Rule
     ↓
Action Group
     ↓
Notification (Email / SMS / Teams / Webhook)

Action Group (Notification)

resource "azurerm_monitor_action_group" "ag" {
  name                = "ag-prod"
  resource_group_name = "rg-monitoring"
  short_name          = "alertgrp"

  email_receiver {
    name          = "admin-email"
    email_address = "admin@example.com"
  }
}




## Metric Alert Example (CPU High)

resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "cpu-high-alert"
  resource_group_name = "rg-monitoring"
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "CPU usage high"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}


Common KQL Queries (Interview Bonus)
🔹 Failed Pods
KubePodInventory
| where PodStatus == "Failed"
🔹 High CPU
Perf
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer

Real-Time Scenario

👉 “Pod going into CrashLoopBackOff”

How you detect:
Container Insights → Pod restarts
Logs in LAW
Alert triggers via KQL

--------------------------------------------------------------------------------------------

Data Sources
📌 What are Data Sources?

👉 Used to fetch existing resources

📌 Example
data "azurerm_resource_group" "rg" {
  name = "existing-rg"
}
📌 Use Case
Use existing VNet
Fetch subnet IDs
Reference existing resources
📌 Example (Real)
data "azurerm_subnet" "subnet" {
  name                 = "subnet1"
  virtual_network_name = "vnet1"
  resource_group_name  = "rg-network"
}

-------------------------------------------------------------------------------------

What is Module?

👉 Reusable Terraform code block

📌 Example Structure
modules/
 ├── vnet/
 ├── aks/
 ├── storage/
 

📌 Module Example

modules/vnet/main.tf

resource "azurerm_virtual_network" "vnet" {
  name                = var.name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.rg_name
}
Root Module
module "vnet" {
  source         = "./modules/vnet"
  name           = "vnet-dev"
  address_space  = ["10.0.0.0/16"]
  location       = "Central India"
  rg_name        = "rg-dev"
}
📌 Module Types
Type	Example
Local	./modules/vnet
Remote	GitHub
Registry	Terraform registry

--------------------------------------------------------------------------------------
count vs for_each 

📌 count
resource "azurerm_resource_group" "rg" {
  count = 2
  name  = "rg-${count.index}"
}
📌 for_each
resource "azurerm_resource_group" "rg" {
  for_each = toset(["dev", "prod"])

  name = "rg-${each.key}"
}
📌 Key Difference
count	for_each
index-based	key-based
less flexible	more flexible
list only	map/set
📌 Interview Tip

“We prefer for_each because it is more stable and avoids index shifting issues.”

🔥 Q&A
Q: What is index shifting problem?

👉 Removing item changes index → resource recreation

-------------------------------------------------------------------------------------------

Big Picture (What we are building)

👉 Goal:

Same Terraform code
Different environments (dev, prod)
Separate:
tfvars (values)
backend (state file)


🔷 2. Final Folder Structure (Enterprise Standard 🔥)
terraform/
│
├── modules/
│   └── aks/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│
├── backend/
│   └── bootstrap.tf   👈 creates storage account
│
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf   👈 DEV backend
│   │
│   ├── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── backend.tf   👈 PROD backend


🔷 3. Step 1 — Bootstrap Backend (Run Once)

👉 backend/bootstrap.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tfstate_rg" {
  name     = "rg-tfstate"
  location = "Central India"
}

resource "azurerm_storage_account" "tfstate_sa" {
  name                     = "sttfstateprod123"
  resource_group_name      = azurerm_resource_group.tfstate_rg.name
  location                 = azurerm_resource_group.tfstate_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_blob_public_access = false
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate_sa.name
  container_access_type = "private"
}


👉 Run this first:
cd backend
terraform init
terraform apply

👉 Now backend is ready



🔷 4. Step 2 — Environment Backend Config (VERY IMPORTANT 🔥)

📌 envs/dev/backend.tf

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateprod123"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
  }
}
📌 envs/prod/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateprod123"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}

🔥 Key Point

👉 Same storage account
👉 Same container
👉 Different state file (key)



🔷 5. Step 3 — Module (AKS)

📌 modules/aks/variables.tf

variable "cluster_name" {}
variable "location" {}
variable "resource_group_name" {}
variable "node_count" {}
variable "vm_size" {}
variable "environment" {}

📌 modules/aks/main.tf

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name       = "nodepool1"
    node_count = var.node_count
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    env = var.environment
  }
}

🔷 6. Step 4 — DEV Environment

📌 envs/dev/variables.tf

variable "cluster_name" {}
variable "location" {}
variable "resource_group_name" {}
variable "node_count" {}
variable "vm_size" {}
variable "environment" {}

📌 envs/dev/terraform.tfvars

cluster_name        = "aks-dev"
location            = "Central India"
resource_group_name = "rg-dev"
node_count          = 1
vm_size             = "Standard_B2s"
environment         = "dev"

📌 envs/dev/main.tf

module "aks" {
  source = "../../modules/aks"

  cluster_name        = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  node_count          = var.node_count
  vm_size             = var.vm_size
  environment         = var.environment
}
🔷 7. Step 5 — PROD Environment
📌 envs/prod/terraform.tfvars
cluster_name        = "aks-prod"
location            = "Central India"
resource_group_name = "rg-prod"
node_count          = 3
vm_size             = "Standard_DS3_v2"
environment         = "prod"

📌 envs/prod/main.tf

👉 Same as dev (no change)

🔷 8. 🔥 END-TO-END FLOW (Most Important)

👉 DEV Deployment
cd envs/dev
terraform init
terraform apply -var-file="terraform.tfvars"
🔁 What happens internally:
backend.tf (dev)
   ↓
connects to → dev.tfstate

terraform.tfvars (dev)
   ↓
values loaded

variables.tf
   ↓
module block (main.tf)
   ↓
modules/aks
   ↓
AKS created (dev config)
👉 PROD Deployment
cd envs/prod
terraform init
terraform apply -var-file="terraform.tfvars"

👉 Uses:

prod.tfvars
prod.tfstate

🔷 9. 🔥 Key Concept (Interview MUST)

👉 Separation:

Component	Purpose
tfvars	    values per env
backend.tf	state per env
module	    reusable code

🔷 10. Real-Time Understanding

👉 DEV:

node_count = 1
state = dev.tfstate

👉 PROD:

node_count = 3
state = prod.tfstate

👉 Same module → different infra

🔷 11. Interview Answer (Perfect 🔥)

“We maintain separate environment folders with their own backend configuration and tfvars files. The backend file ensures each environment uses a separate state file, while tfvars inject environment-specific values into variables. These values are passed to reusable modules like AKS, allowing us to deploy the same infrastructure with different configurations per environment.”


Separate storage account per env
Separate subscriptions per env
🔷 14. Rapid Fire 🔥
Backend → where state stored
Key → state file name
tfvars → values
module → reusable infra
env folder → isolation

------------------------------------------------------------------------------------------------------------------------------------------------------

3- Tier archietecture connection

Tier	     Purpose	        Example
Web Tier	 Entry point	   App Gateway / Frontend
App Tier	 Business logic    AKS / API
DB Tier	Data storage	       Azure SQL / DB

2. End-to-End Flow (Simple)
User → App Gateway → AKS (Ingress → Service → Pod) → Database

🔷 3. Network Design (VERY IMPORTANT 🔥)
📌 VNet + Subnets
Subnet	        Purpose
appgw-subnet	Application Gateway
aks-subnet	    AKS nodes
db-subnet	    Database

📌 Example CIDR
VNet: 10.0.0.0/16

appgw-subnet → 10.0.1.0/24  
aks-subnet   → 10.0.2.0/24  
db-subnet    → 10.0.3.0/24  
🔷 4. NSG (Network Security Group)

👉 Controls traffic at subnet/NIC level

📌 Example Rules
🔹 App Gateway NSG
Allow: Internet → 80/443
Allow: AppGW → AKS
🔹 AKS NSG
Allow: AppGW subnet → AKS
Deny: Internet direct access ❌
🔹 DB NSG
Allow: AKS subnet → DB port (1433)
Deny: All other ❌

PART 1: ASG + NSG (Simple & Clear)

📌 First understand the problem

👉 Without ASG, NSG rules look like this:

Allow 10.0.2.0/24 → 10.0.3.0/24 (port 1433)

❌ Problem:

Hard to manage
IP changes → rules break
📌 Solution: ASG (Logical Grouping)

👉 Instead of IPs, we group resources:

asg-app → AKS nodes
asg-db  → Database
📌 How it works (step-by-step)
1️⃣ Create ASGs
asg-app → attach to AKS nodes (NICs)
asg-db → attach to DB (or private endpoint NIC)
2️⃣ Create NSG rule using ASG

👉 Now rule becomes:

ALLOW asg-app → asg-db on port 1433
📌 Terraform Example
resource "azurerm_application_security_group" "asg_app" {
  name                = "asg-app"
  location            = "Central India"
  resource_group_name = "rg-network"
}

resource "azurerm_application_security_group" "asg_db" {
  name                = "asg-db"
  location            = "Central India"
  resource_group_name = "rg-network"
}
📌 NSG Rule using ASG
security_rule {
  name     = "allow-app-to-db"
  priority = 100

  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_application_security_group_ids      = [azurerm_application_security_group.asg_app.id]
  destination_application_security_group_ids = [azurerm_application_security_group.asg_db.id]

  destination_port_range = "1433"
}
📌 Final Understanding (IMPORTANT)

👉 You are NOT connecting subnets
👉 You are connecting logical groups of resources

🔥 Interview Line

“We use ASGs to logically group resources like AKS and DB, and NSGs reference these groups instead of IPs, making rules scalable and easier to manage.”

App Gateway + AKS (Ingress)

📌 Flow
User → App Gateway → Ingress Controller → Service → Pod
📌 Key Components
App Gateway (WAF optional)
AGIC (Application Gateway Ingress Controller)
Kubernetes Ingress

📌 Ingress YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  rules:
  - host: myapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
			  
🔷 7. AKS Internal Flow

Ingress → Service → Pod

📌 Service Example
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080

	  
PART 2: AKS → DB Connection (FULL FLOW)

Now let’s connect everything clearly.

🔷 Step 1: Private Networking (VERY IMPORTANT)

👉 DB should NOT be public

So we use:

Private Endpoint
Inside same VNet
📌 Flow
AKS (10.0.2.x) → Private Endpoint → DB (10.0.3.x)

Private Endpoint (Private Access to Azure Services)

resource "azurerm_private_endpoint" "pe" {
  name                = "pe-db"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_app.id

  private_service_connection {
    name                           = "pe-connection"
    private_connection_resource_id = azurerm_storage_account.db.id
    subresource_names              = ["db-01"]
    is_manual_connection           = false
  }
}

“I’m creating a Private Endpoint to access the DB over a private IP within the VNet instead of using public internet.”

👉 No internet involved


🔷 Step 2: JDBC Connection (App Level)

Your application (Java API) connects like this:

jdbc:sqlserver://mydb.privatelink.database.windows.net:1433;
database=mydb;
user=admin;
password=*****


🔷 Step 3: Where do we store username/password?

❌ NEVER in code
❌ NEVER in tfvars

👉 Use:

Azure Key Vault ✅
🔷 Step 4: Store Secrets in Key Vault
Secret Name: db-username
Secret Name: db-password
🔷 Step 5: AKS Access to Key Vault

👉 Use:

Managed Identity (AKS)
OR Workload Identity
📌 Flow
AKS Pod → Managed Identity → Key Vault → Secrets

🔷 Step 6: Inject into Kubernetes

You have 2 options:

✅ Option 1: CSI Driver (BEST PRACTICE)

👉 Key Vault → mounted into pod


DB_USER
DB_PASSWORD
DB_HOST

👉 Builds JDBC string dynamically

🔷 FULL END-TO-END FLOW (VERY IMPORTANT)
User
 ↓
App Gateway
 ↓
AKS Ingress
 ↓
Pod (Java API)
 ↓
Fetch secrets from Key Vault
 ↓
Build JDBC URL
 ↓
Connect via Private Endpoint
 ↓
Azure SQL DB


🔷 🔥 Putting BOTH Together (FINAL CLARITY)
Networking Security
ASG:
asg-app (AKS)
asg-db (DB)
NSG rule:
👉 allow asg-app → asg-db (1433)
Application Security
Secrets:Stored in Key Vault
Access:Managed Identity
Usage:Inject into pod

------------------------------------------------------------------------------------------

## CI/CD Integration (Terraform in Azure DevOps)

1. High-Level Flow (WIF Pipeline)

Developer → Azure Repo
        ↓
Pipeline triggered
        ↓
Azure DevOps Service Connection (WIF)
        ↓
OIDC Token generated
        ↓
Azure AD validates federation
        ↓
Access Token issued
        ↓
Terraform → Azure API
        ↓
Resources created + state stored in backend


🔷 2. One-Time Setup (VERY IMPORTANT 🔥)
✅ Step 1: Create Service Connection

In Azure DevOps:

Type → Azure Resource Manager
Identity → App registration (automatic)
Credential → Workload Identity Federation

👉 This creates:

App Registration (SPN)
Federated credential



✅ Step 2: Assign RBAC

Assign roles to Service Principal

# Infra
Contributor

# Backend
Storage Blob Data Contributor

# Key Vault
Key Vault Secrets User

1. First Understand (VERY IMPORTANT)

👉 Even in Workload Identity Federation (WIF):

A Service Principal (App Registration) is created
👉 RBAC is assigned to that SPN
👉 Pipeline uses that SPN via OIDC (no secret)
🔷 2. Required RBAC Roles (Enterprise Standard 🔥)
Purpose	Role
Create Infra (AKS, VNet, etc.)	Contributor
Terraform Backend (Storage)	Storage Blob Data Contributor
Key Vault (Secrets)	Key Vault Secrets User
🔷 3. Where Do You Get SPN ID?

After creating service connection:

👉 Go to:

Azure Portal → App Registrations
Find your app

👉 Copy:

Application (Client) ID

Example
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "contributor" {
  scope                = "/subscriptions/<sub-id>"
  role_definition_name = "Contributor"
  principal_id         = "<spn-object-id>"
}
📌 Storage Access
resource "azurerm_role_assignment" "storage" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = "<spn-object-id>"
}
📌 Key Vault Access
resource "azurerm_role_assignment" "kv" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = "<spn-object-id>"
}

Pipeline
   ↓
Service Connection (WIF)
   ↓
OIDC Token
   ↓
Azure AD
   ↓
Maps to SPN
   ↓
RBAC applied
   ↓
Access Azure resources

✅ Step 3: Backend Ready

Already created via bootstrap.tf

🔷 3. Terraform Pipeline (WIF Enabled)

👉 No client secret needed ❌
👉 No env vars needed ❌

📌 Full YAML (Enterprise Style 🔥)
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
🔷 4. 🔥 What Makes This WIF?

👉 This line:

azureSubscription: $(SERVICE_CONNECTION)
Behind the scenes:
Azure DevOps → OIDC token
        ↓
Azure AD (federation)
        ↓
Access token issued
        ↓
Terraform uses it

“In a WIF-based setup, Azure DevOps uses a service connection linked to a service principal. We assign RBAC roles like Contributor, Storage Blob Data Contributor, and Key Vault Secrets User to that service principal. During pipeline execution, Azure AD maps the OIDC token to the service principal, and RBAC controls access to Azure resources.”
