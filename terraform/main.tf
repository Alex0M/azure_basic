provider "azurerm" {
    version = "=2.20.0"
    subscription_id = var.subscription_id
    features {}
}

# Data template cloud-init file
data "template_file" "app-vm-cloud-init" {
  template = file("cloud-init.txt")
}


resource "azurerm_resource_group" "main" {
    name            = "demo-${var.env_tag}-rg"
    location        = var.location
}

##Create Vnet and subnet

resource "azurerm_virtual_network" "main" {
  name          = "demo-${var.env_tag}-vnet"
  location      = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space = ["10.19.0.0/16"]
}

resource "azurerm_subnet" "app-subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.19.0.0/24"]
}

resource "azurerm_subnet" "jumpbox-subnet" {
  name                 = "jumpbox-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.19.1.0/24"]
}

##Create NSG

resource "azurerm_network_security_group" "app-nsg" {
  name                = "demo-${var.env_tag}-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowAppPort"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app-nsg" {
  subnet_id                 = azurerm_subnet.app-subnet.id
  network_security_group_id = azurerm_network_security_group.app-nsg.id
}


resource "azurerm_network_security_group" "jumpbox-nsg" {
  name                = "demo-${var.env_tag}-jumpbox-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowSSHPort"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox-nsg" {
  subnet_id                 = azurerm_subnet.jumpbox-subnet.id
  network_security_group_id = azurerm_network_security_group.jumpbox-nsg.id
}

##Create load balancer

resource "azurerm_public_ip" "main" {
 name                         = "demo-${var.env_tag}-lb-pip"
 location                     = azurerm_resource_group.main.location
 resource_group_name          = azurerm_resource_group.main.name
 allocation_method            = "Static"
}

resource "azurerm_lb" "main" {
 name                = "demo-${var.env_tag}-lb"
 location            = azurerm_resource_group.main.location
 resource_group_name = azurerm_resource_group.main.name

 frontend_ip_configuration {
   name                 = "demo-frontend"
   public_ip_address_id = azurerm_public_ip.main.id
 }
}

resource "azurerm_lb_probe" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "demo-app-prove"
  port                = 80
}

resource "azurerm_lb_backend_address_pool" "main" {
 resource_group_name = azurerm_resource_group.main.name
 loadbalancer_id     = azurerm_lb.main.id
 name                = "demo-backend-pool"
}

resource "azurerm_lb_rule" "main" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "demo-app-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.main.id
  probe_id                       = azurerm_lb_probe.main.id
  frontend_ip_configuration_name = "demo-frontend"
}

##Create app vms

resource "azurerm_availability_set" "main" {
 name                         = "demo-${var.env_tag}-avset"
 location                     = azurerm_resource_group.main.location
 resource_group_name          = azurerm_resource_group.main.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 5
 managed                      = true
}

resource "azurerm_network_interface" "main" {
  count               = var.vm_count
  name                = "demo-${var.env_tag}-nic-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.vm_count
  network_interface_id    = element(azurerm_network_interface.main.*.id, count.index)
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_virtual_machine" "test" {
 count                 = var.vm_count
 name                  = "demo-app-${count.index}"
 location              = azurerm_resource_group.main.location
 availability_set_id   = azurerm_availability_set.main.id
 resource_group_name   = azurerm_resource_group.main.name
 network_interface_ids = [element(azurerm_network_interface.main.*.id, count.index)]
 vm_size               = "Standard_B1ms"


 
 delete_os_disk_on_termination = true


 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "18.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "demo-app-${count.index}-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "demo-app-${count.index}"
   admin_username = "azureuser"
   admin_password = var.vm_pass
   custom_data           = base64encode(data.template_file.app-vm-cloud-init.rendered)
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }
}