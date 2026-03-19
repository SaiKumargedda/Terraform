
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
