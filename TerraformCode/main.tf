terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.32.0"
    }

      }
  backend "azurerm" {}
}

provider "azurerm" {
   features {}
 }



data "azurerm_client_config" "current" {}

output "object_id" {
  value = data.azuread_client_config.current.object_id
}

locals {

  current_instance_env = "{var.ENVIRONMENT}"
  lower_environments = ["sb" ]
  
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  #address_space       = ["10.0.0.0/16"]        
   address_space       =  [var.vnet_address_space]
}

# ............................. Define  Subnet for web Layer..................1....................

 /* creating  a subnet and an associated Network Security Group (NSG) for the Web Tier in Azure.
    The Web Tier will allow inbound HTTP (80) and
     HTTPS (443) traffic while restricting access based on security best practices.
 */

resource "azurerm_subnet" "web_subnet" {
  name                 = var.web_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
# Create Network Security Group (NSG) for Web Tier

resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-web-sb-eu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# Allow inbound HTTP traffic (Port 80)

resource "azurerm_network_security_rule" "web_allow_http" {
  name                        = "allow-http"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.web_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow SSH Traffic (Port 22) - Secure Access for Admins

resource "azurerm_network_security_rule" "web_allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "Internet" # You can restrict this to your office/public IP for security
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.web_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow inbound HTTPS traffic (Port 443)

resource "azurerm_network_security_rule" "web_allow_https" {
  name                        = "allow-https"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.web_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow outbound traffic to the Application Tier (Port 8080)

resource "azurerm_network_security_rule" "web_allow_app" {
  name                        = "allow-app-tier"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_subnet.app_subnet.address_prefixes[0] # Application Tier Subnet
  network_security_group_name = azurerm_network_security_group.web_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Associate NSG with Web Subnet

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_subnet
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# Create Network Interface for Web VM
resource "azurerm_network_interface" "web_vm_nic" {
  name                = "nic-web-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "web-nic-ip-config"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

/* # Create Web VM
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                = "web-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.web_vm_nic.id
  ]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub") # Ensure SSH key is available
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
} */

# To provide high availability to architecture,created a VM scale sets for the web-tier
# in future as per requirement we can update it 

# Create Availability Set for Web VMs
resource "azurerm_availability_set" "web_avset" {
  name                         = "avset-web-sb-eu"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true

  
}

# Define Web VM with Premium Storage
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                = "web-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.web_vm_nic.id
  ]
  availability_set_id = azurerm_availability_set.web_avset.id

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # Define storage type here
  }
}

# Capture Web VM Image
resource "azurerm_image" "web_vm_image" {
  name                = "web-vm-image-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  source_virtual_machine_id = azurerm_linux_virtual_machine.web_vm.id
}

# Deploy New Web VM using the Captured Image
resource "azurerm_linux_virtual_machine" "web_vm_new" {
  name                = "web-vm-new-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.web_vm_nic.id
  ]
  availability_set_id = azurerm_availability_set.web_avset.id

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # Required even when using an image
  }

  source_image_id = azurerm_image.web_vm_image.id
}

# ...............................Create Subnet for Application Layer  ...2...............

/*creating a Subnet and Network Security Group (NSG) for the Application Tier in an Azure Virtual Network (VNet). This will include subnet creation, NSG setup, 
security rules, and association. */

resource "azurerm_subnet" "app_subnet" {
  name                 = var.app_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Group (NSG) for Application Tier
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-app-sb-eu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# Allow inbound traffic from Web Tier to Application Tier on port 8080
resource "azurerm_network_security_rule" "app_allow_web" {
  name                        = "allow-web-tier"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = azurerm_subnet.web_subnet.address_prefixes[0] # Web Tier Subnet
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.app_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}
# Allow outbound traffic to Database Tier on port 3306 (MySQL) or 1433 (SQL Server)
resource "azurerm_network_security_rule" "app_allow_db" {
  name                        = "allow-db-tier"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306" # Change to 1433 if using SQL Server
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_subnet.db_subnet.address_prefixes[0] # Database Tier Subnet
  network_security_group_name = azurerm_network_security_group.app_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}
# Allow SSH Traffic (Port 22) - Secure Access for Admins
resource "azurerm_network_security_rule" "app_allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "Internet" # Change this to a specific IP range for better security
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.app_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow Application Traffic (Port 4000)
resource "azurerm_network_security_rule" "app_allow_4000" {
  name                        = "allow-app-port"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "4000"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.app_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Deny All Other Inbound Traffic for Security
resource "azurerm_network_security_rule" "app_deny_all" {
  name                        = "deny-all"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.app_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Associate NSG with Application Subnet
resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}


# Create Network Interface for App VM
resource "azurerm_network_interface" "app_vm_nic" {
  name                = "nic-app-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "app-nic-ip-config"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create App VM
/* resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "app-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.app_vm_nic.id
  ]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub") # Ensure SSH key is available
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
} */

# To provide high availability to architecture,created a VM scale sets for the App-tier
# in future as per requirement we can update it 

# Create Availability Set for App VMs
resource "azurerm_availability_set" "app_avset" {
  name                         = "avset-app-sb-eu"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Define App VM with Premium Storage
resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "app-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.app_vm_nic.id
  ]
  availability_set_id = azurerm_availability_set.app_avset.id

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS" # Define storage type here
  }
}

# Capture App VM Image
resource "azurerm_image" "app_vm_image" {
  name                = "app-vm-image-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  source_virtual_machine_id = azurerm_linux_virtual_machine.app_vm.id
}

# Deploy New App VM using the Captured Image
resource "azurerm_linux_virtual_machine" "app_vm_new" {
  name                = "app-vm-new-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.app_vm_nic.id
  ]
  availability_set_id = azurerm_availability_set.app_avset.id

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # Required even when using an image
  }

  source_image_id = azurerm_image.app_vm_image.id
}

/* From Below snippet is for creating  an Internal load balancer to balance the traffic from the 
frontend web-tier to the backend app-tier */

# Create Internal Load Balancer for App Tier
resource "azurerm_lb" "app_ilb" {
  name                = "app-internal-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard" # Standard Load Balancer supports zone redundancy
  frontend_ip_configuration {
    name                          = "app-ilb-frontend"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10" # need to Adjust based on our App Subnet range
  }
}

# Backend Pool (Assign App VMs)
resource "azurerm_lb_backend_address_pool" "app_backend_pool" {
  loadbalancer_id = azurerm_lb.app_ilb.id
  name            = "app-backend-pool"
}

# Associate App VMs with Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "app_vm_backend" {
  for_each            = { for idx, vm in azurerm_linux_virtual_machine.app_vm : idx => vm }
  network_interface_id = azurerm_network_interface.app_vm_nic[each.key].id
  ip_configuration_name = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_backend_pool.id
}

# Health Probe for App Tier VMs (Check Port 4000)
resource "azurerm_lb_probe" "app_health_probe" {
  loadbalancer_id = azurerm_lb.app_ilb.id
  name            = "app-health-probe"
  port            = 4000 # Ensure app listens on this port
  protocol        = "Tcp"
}

# Load Balancing Rule to Forward Traffic from Web to App
resource "azurerm_lb_rule" "app_lb_rule" {
  loadbalancer_id                = azurerm_lb.app_ilb.id
  name                           = "app-tier-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 4000  # Incoming traffic to the App-tier
  backend_port                   = 4000  # App listens on this port
  frontend_ip_configuration_name = "app-ilb-frontend"
  #backend_address_pool_id        = azurerm_lb_backend_address_pool.app_backend_pool.id
  
  probe_id                       = azurerm_lb_probe.app_health_probe.id
}
#............................. Defining a  Subnet for Database Layer.......... 3

 /* Creating a subnet and an associated Network Security Group (NSG) for the Database (DB) Tier in Azure. 
 The DB tier will only allow inbound traffic from the Application Tier and block direct internet 
 access for security. */

# Create Subnet for Database Layer (MySQL Flexible Server)

resource "azurerm_subnet" "db_subnet" {
  name                 = var.web_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_address_space]  # CIDR range ...............
}

# Create Network Security Group (NSG) for Database Tier (MySQL Server Subnet )
resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db-sb-eu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow inbound traffic from Application Tier on database ports (MySQL: 3306, SQL Server: 1433)
resource "azurerm_network_security_rule" "db_allow_app" {
  name                        = "allow-app-tier"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306" # Use 1433 for SQL Server
  source_address_prefix       = azurerm_subnet.app_subnet.address_prefixes[0] # Application Tier Subnet
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Deny all internet access to DB Tier
resource "azurerm_network_security_rule" "db_deny_internet" {
  name                        = "deny-internet"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Allow outbound traffic from DB Tier to App Tier for responses
resource "azurerm_network_security_rule" "db_allow_outbound_app" {
  name                        = "allow-outbound-app"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_subnet.app_subnet.address_prefixes[0]
  network_security_group_name = azurerm_network_security_group.db_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Associate NSG with Database Subnet
resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}


# Create MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "mysql_DBServer" {
  name                   = var.my_sql_Server
  resource_group_name    = var.rg_name
  location               = var.rg_name.location
  administrator_login    = "psqladmin"   #need to create Keyvault 
  administrator_password = "H@Sh1CoR3!"
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.db_subnet.id
   sku_name               = "GP_Standard_D2ds_v4"
}

#/ ......................... Define Subnet for Azure Bastion Host **************4 ************** /

/* deploy an Azure Bastion host for secure remote access to VMs without exposing them 
directly to the internet.
It will:  Create a dedicated Bastion Subnet , Deploy an Azure Bastion Host
Configure a Network Security Group (NSG) to allow SSH traffic (port 22) */

resource "azurerm_subnet" "bastion_subnet" {
  name                 = var.bastion_subnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.5.0/27"] # Required CIDR for Bastion
}

# Create Network Security Group for Bastion
resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "nsg-bastion-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule {
    name                       = "AllowBastionInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# Allow SSH (Port 22) Access for Secure VM Login
resource "azurerm_network_security_rule" "bastion_allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Deny All Other Internet Traffic for Security

resource "azurerm_network_security_rule" "bastion_deny_all" {
  name                        = "deny-all"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Associate NSG with Bastion Subnet
resource "azurerm_subnet_network_security_group_association" "bastion_nsg_assoc" {
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}

# Create Public IP for Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-pip-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Deploy Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
  depends_on = [azurerm_subnet.bastion_subnet]
}


# Create Ubuntu VM in Bastion Subnet
resource "azurerm_network_interface" "bastion_vm_nic" {
  name                = "nic-bastion-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "bastion-nic-ip-config"
    subnet_id                     = azurerm_subnet.bastion_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "bastion_vm" {
  name                = "bastion-vm-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  network_interface_ids = [
    azurerm_network_interface.bastion_vm_nic.id
  ]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub") # Ensure your SSH key is correctly set up
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
 
/*  15 Now we create an Application Gateway to allow public access to our web servers and 
also to load balance the incoming traffic from the web. */

# Configure Azure DNS with Application Gateway

# Step 1: Create Azure DNS Zone
resource "azurerm_dns_zone" "my_dns_zone" {
  name                = "mydomain.com"  # Replace with your domain
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnet for Application Gateway
resource "azurerm_subnet" "appgw_subnet" {
  name                 = var.appgw_subnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "pip-appgw-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                = "Standard"
}
# Create Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-sb-eu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

# Auto-scaling for App Gateway
  sku {
    name     = "WAF_v2"  # Standard_v2 or WAF_v2 support autoscaling
    tier     = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }


  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }

  frontend_port {
    name = "appgw-http-port"
    port = 80
  }

  frontend_port {
    name = "appgw-https-port"
    port = 443
  }

  ssl_certificate {
    name     = "appgw-ssl-cert"
    data     = filebase64("${path.module}/cert.pfx") # Upload the SSL Certificate
    password = "YourPfxPasswordHere" # Store it securely in Key Vault == pending 
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "appgw-backend-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "appgw-http-port"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "appgw-https-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "appgw-https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-ssl-cert"
  }

  request_routing_rule {
    name                       = "appgw-http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http"
    priority                   = 100
  }

  request_routing_rule {
    name                       = "appgw-https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-https-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http"
    priority                   = 110
  }

  depends_on = [azurerm_subnet_network_security_group_association.web_nsg_assoc]
}
/*  integrate App Gateway in front of the Web-tier To provide a scalable, secure, and highly 
available entry point for your web-tier, we will deploy an Azure Application Gateway (App Gateway)
in front of the web-tier VMs.
 */
 
 # Associate Web VMs with Application Gateway Backend Pool
resource "azurerm_application_gateway_backend_address_pool" "web_backend_pool" {
  application_gateway_id = azurerm_application_gateway.appgw.id
  name                   = "web-backend-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "web_vm_backend" {
  for_each                = { for idx, vm in azurerm_linux_virtual_machine.web_vm : idx => vm }
  network_interface_id    = azurerm_network_interface.web_vm_nic[each.key].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_application_gateway_backend_address_pool.web_backend_pool.id
}

# : Create DNS A Record for Application Gateway
resource "azurerm_dns_a_record" "appgw_dns" {
  name                =  "app.maheshdomain.com"  
  zone_name           = azurerm_dns_zone.my_dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_public_ip.appgw_public_ip.allocation_method]


}

# : (Optional) CNAME Record for Subdomains
/* resource "azurerm_dns_cname_record" "appgw_cname" {
  name                = "app.maheshdomain.com"
  zone_name           = azurerm_dns_zone.my_dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_public_ip.appgw_pip.fqdn
} */


/**********eof ************/

# Monitoring and scaling strategies.

# 1. Monitoring App Gateway Logs

resource "azurerm_monitor_diagnostic_setting" "appgw_logs" {
  name                       = "appgw-diagnostics"
  target_resource_id         = azurerm_application_gateway.appgw.id
  
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  metric {
    category = "AllMetrics"
  }
}


/* Alerting & Automation : Alerting on High CPU Usage and Azure Alerts & Action Groups 
and CPU Alert with Action Group */

resource "azurerm_monitor_action_group" "notify_team" {
  name                = "notify-team"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "notify"

  email_receiver {
    name          = "devops-team"
    email_address = "devops@example.com"
  }
}

resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "cpu-high-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes             = [azurerm_linux_virtual_machine.web_vm.id]
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  action {
    action_group_id = azurerm_monitor_action_group.notify_team.id
  }
}

