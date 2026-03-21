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

