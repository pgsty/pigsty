#==============================================================#
# File      :   linode.tf
# Desc      :   1-node pigsty meta for Linode/Akamai (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/linode.tf
# Docs      :   https://pigsty.io/docs/deploy/terraform
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#


#===========================================================#
# Variables
#===========================================================#
variable "distro" {
  description = "The distro code (d12 or d13)"
  type        = string
  default     = "d12"      # d12 = Debian 12, d13 = Debian 13
}

variable "region" {
  description = "Linode region"
  type        = string
  default     = "us-west"  # us-east, us-central, us-west, eu-west, ap-south, etc.
}

variable "root_pass" {
  description = "Root password for the instance (min 11 chars, needs uppercase, lowercase, number)"
  type        = string
  default     = "PigstyDemo4!"  # Must meet Linode password complexity requirements
  sensitive   = true
}

locals {
  disk_size = 40  # Linode plans have fixed disk sizes

  # Linode instance types (Shared CPU)
  # g6-nanode-1: 1 vCPU, 1GB RAM, 25GB SSD, $5/mo
  # g6-standard-1: 1 vCPU, 2GB RAM, 50GB SSD, $12/mo
  # g6-standard-2: 2 vCPU, 4GB RAM, 80GB SSD, $24/mo
  instance_type = "g6-standard-2"  # 2 vCPU, 4GB RAM

  # Linode image IDs
  image_map = {
    d12 = "linode/debian12"
    d13 = "linode/debian13"
  }

  selected_image = local.image_map[var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Add your Linode API token via environment variable:
# export LINODE_TOKEN="????????????????????"
provider "linode" {
  # token = "????????????????????"
}


#===========================================================#
# Firewall
#===========================================================#
resource "linode_firewall" "pigsty_fw" {
  label = "pigsty-fw"

  # Allow all inbound (demo only - restrict in production!)
  inbound {
    label    = "allow-all-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-all-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # Allow all outbound
  outbound {
    label    = "allow-all-outbound"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  outbound {
    label    = "allow-all-outbound-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.pg-meta.id]
}


#===========================================================#
# Linode Instance: pg-meta
#===========================================================#
resource "linode_instance" "pg-meta" {
  label           = "pg-meta"
  image           = local.selected_image
  region          = var.region
  type            = local.instance_type
  root_pass       = var.root_pass
  authorized_keys = [chomp(file("~/.ssh/id_rsa.pub"))]
  private_ip      = true  # Enable private networking (192.168.x.x range)

  tags = ["pigsty", "pg-meta"]
}


#===========================================================#
# Output
#===========================================================#
output "meta_ip" {
  description = "Public IP of pg-meta instance"
  value       = linode_instance.pg-meta.ip_address
}

output "meta_private_ip" {
  description = "Private IP of pg-meta instance (auto-assigned)"
  value       = linode_instance.pg-meta.private_ip_address
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${linode_instance.pg-meta.ip_address}"
}
