#==============================================================#
# File      :   azure.tf
# Desc      :   1-node pigsty meta for Azure (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/azure.tf
# Docs      :   https://pigsty.io/docs/deploy/terraform
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#


#===========================================================#
# Architecture, Instance Type, OS Images
#===========================================================#
variable "architecture" {
  description = "The architecture type (amd64 or arm64)"
  type        = string
  default     = "amd64"    # comment this to use arm64
  #default     = "arm64"   # uncomment this to use arm64
}

variable "distro" {
  description = "The distro code (d12 or d13)"
  type        = string
  default     = "d12"      # d12 = Debian 12, d13 = Debian 13
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"   # or westus2, westeurope, etc.
}

variable "admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "pigsty"
}

locals {
  disk_size = 40  # system disk size in GB

  # VM sizes: Standard_B2s for amd64, Standard_B2ps_v2 for arm64
  vm_size_map = {
    amd64 = "Standard_B2s"       # 2 vCPU, 4 GiB
    arm64 = "Standard_B2ps_v2"   # 2 vCPU, 4 GiB (Arm-based)
  }

  # Debian image references
  # Publisher: Debian, Offer: debian-12 / debian-13
  image_map = {
    amd64 = {
      d12 = {
        publisher = "Debian"
        offer     = "debian-12"
        sku       = "12-gen2"
        version   = "latest"
      }
      d13 = {
        publisher = "Debian"
        offer     = "debian-13"
        sku       = "13-gen2"
        version   = "latest"
      }
    }
    arm64 = {
      d12 = {
        publisher = "Debian"
        offer     = "debian-12"
        sku       = "12-arm64"
        version   = "latest"
      }
      d13 = {
        publisher = "Debian"
        offer     = "debian-13"
        sku       = "13-arm64"
        version   = "latest"
      }
    }
  }

  selected_vm_size = local.vm_size_map[var.architecture]
  selected_image   = local.image_map[var.architecture][var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Authenticate via Azure CLI: az login
# Or use environment variables:
# export ARM_CLIENT_ID="????????????????????"
# export ARM_CLIENT_SECRET="????????????????????"
# export ARM_SUBSCRIPTION_ID="????????????????????"
# export ARM_TENANT_ID="????????????????????"
provider "azurerm" {
  features {}
}


#===========================================================#
# Resource Group
#===========================================================#
resource "azurerm_resource_group" "pigsty_rg" {
  name     = "pigsty-rg"
  location = var.location
  tags = {
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Virtual Network
#===========================================================#
resource "azurerm_virtual_network" "pigsty_vnet" {
  name                = "pigsty-vnet"
  address_space       = ["10.10.10.0/24"]
  location            = azurerm_resource_group.pigsty_rg.location
  resource_group_name = azurerm_resource_group.pigsty_rg.name
  tags = {
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Subnet
#===========================================================#
resource "azurerm_subnet" "pigsty_subnet" {
  name                 = "pigsty-subnet"
  resource_group_name  = azurerm_resource_group.pigsty_rg.name
  virtual_network_name = azurerm_virtual_network.pigsty_vnet.name
  address_prefixes     = ["10.10.10.0/24"]
}


#===========================================================#
# Network Security Group
#===========================================================#
resource "azurerm_network_security_group" "pigsty_nsg" {
  name                = "pigsty-nsg"
  location            = azurerm_resource_group.pigsty_rg.location
  resource_group_name = azurerm_resource_group.pigsty_rg.name

  # Allow all inbound (restrict in production!)
  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}

resource "azurerm_subnet_network_security_group_association" "pigsty_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pigsty_subnet.id
  network_security_group_id = azurerm_network_security_group.pigsty_nsg.id
}


#===========================================================#
# Public IP
#===========================================================#
resource "azurerm_public_ip" "pigsty_pip" {
  name                = "pigsty-pip"
  location            = azurerm_resource_group.pigsty_rg.location
  resource_group_name = azurerm_resource_group.pigsty_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Network Interface
#===========================================================#
resource "azurerm_network_interface" "pigsty_nic" {
  name                = "pigsty-nic"
  location            = azurerm_resource_group.pigsty_rg.location
  resource_group_name = azurerm_resource_group.pigsty_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pigsty_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.10.10"
    public_ip_address_id          = azurerm_public_ip.pigsty_pip.id
  }

  tags = {
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Virtual Machine: pg-meta
#===========================================================#
resource "azurerm_linux_virtual_machine" "pg-meta" {
  name                = "pg-meta"
  resource_group_name = azurerm_resource_group.pigsty_rg.name
  location            = azurerm_resource_group.pigsty_rg.location
  size                = local.selected_vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.pigsty_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")  # or use your own key path
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = local.disk_size
  }

  source_image_reference {
    publisher = local.selected_image.publisher
    offer     = local.selected_image.offer
    sku       = local.selected_image.sku
    version   = local.selected_image.version
  }

  computer_name = "pg-meta"

  tags = {
    Name      = "pg-meta"
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Output
#===========================================================#
output "meta_ip" {
  description = "Public IP of pg-meta instance"
  value       = azurerm_public_ip.pigsty_pip.ip_address
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/id_rsa ${var.admin_username}@${azurerm_public_ip.pigsty_pip.ip_address}"
}
