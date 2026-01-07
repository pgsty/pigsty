#==============================================================#
# File      :   vultr.tf
# Desc      :   1-node pigsty meta for Vultr (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/vultr.tf
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
  description = "Vultr region ID"
  type        = string
  default     = "lax"      # lax (LA), sjc (SV), ewr (NJ), ams, fra, sgp, nrt (Tokyo)
}

locals {
  # Vultr plan IDs
  # vc2-1c-1gb: 1 vCPU, 1GB RAM, 25GB SSD, $5/mo
  # vc2-1c-2gb: 1 vCPU, 2GB RAM, 55GB SSD, $10/mo
  # vc2-2c-4gb: 2 vCPU, 4GB RAM, 80GB SSD, $20/mo
  plan = "vc2-2c-4gb"  # 2 vCPU, 4GB RAM

  # Vultr OS IDs (use data source to get dynamically)
  # Debian 12: os_id = 2136
  # Debian 13: os_id = TBD (check vultr_os data source)
  os_map = {
    d12 = "Debian 12 x64 (bookworm)"
    d13 = "Debian 13 x64 (trixie)"
  }

  selected_os = local.os_map[var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.0"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Add your Vultr API key via environment variable:
# export VULTR_API_KEY="????????????????????"
provider "vultr" {
  # api_key = "????????????????????"
}


#===========================================================#
# Data Sources
#===========================================================#
# Get OS ID dynamically
data "vultr_os" "debian" {
  filter {
    name   = "name"
    values = [local.selected_os]
  }
}


#===========================================================#
# SSH Key
#===========================================================#
resource "vultr_ssh_key" "pigsty_key" {
  name    = "pigsty-key"
  ssh_key = file("~/.ssh/id_rsa.pub")
}


#===========================================================#
# VPC 2.0
#===========================================================#
resource "vultr_vpc2" "pigsty_vpc" {
  description    = "Pigsty VPC Network"
  region         = var.region
  ip_block       = "10.10.10.0"
  prefix_length  = 24
}


#===========================================================#
# Firewall Group
#===========================================================#
resource "vultr_firewall_group" "pigsty_fw" {
  description = "Pigsty Firewall Group"
}

# Allow all inbound TCP (demo only - restrict in production!)
resource "vultr_firewall_rule" "allow_tcp" {
  firewall_group_id = vultr_firewall_group.pigsty_fw.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "1:65535"
  notes             = "Allow all TCP"
}

resource "vultr_firewall_rule" "allow_tcp_v6" {
  firewall_group_id = vultr_firewall_group.pigsty_fw.id
  protocol          = "tcp"
  ip_type           = "v6"
  subnet            = "::"
  subnet_size       = 0
  port              = "1:65535"
  notes             = "Allow all TCP IPv6"
}

resource "vultr_firewall_rule" "allow_udp" {
  firewall_group_id = vultr_firewall_group.pigsty_fw.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "1:65535"
  notes             = "Allow all UDP"
}

resource "vultr_firewall_rule" "allow_icmp" {
  firewall_group_id = vultr_firewall_group.pigsty_fw.id
  protocol          = "icmp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  notes             = "Allow ICMP"
}


#===========================================================#
# Reserved IP (optional)
#===========================================================#
resource "vultr_reserved_ip" "pigsty_ip" {
  region       = var.region
  ip_type      = "v4"
  instance_id  = vultr_instance.pg-meta.id
  label        = "pigsty-ip"
}


#===========================================================#
# Instance: pg-meta
#===========================================================#
resource "vultr_instance" "pg-meta" {
  label             = "pg-meta"
  hostname          = "pg-meta"
  region            = var.region
  plan              = local.plan
  os_id             = data.vultr_os.debian.id
  ssh_key_ids       = [vultr_ssh_key.pigsty_key.id]
  firewall_group_id = vultr_firewall_group.pigsty_fw.id
  vpc2_ids          = [vultr_vpc2.pigsty_vpc.id]

  enable_ipv6       = true
  backups           = "disabled"
  ddos_protection   = false
  activation_email  = false

  tags = ["pigsty", "pg-meta"]
}


#===========================================================#
# Output
#===========================================================#
output "meta_ip" {
  description = "Public IP of pg-meta instance (reserved)"
  value       = vultr_reserved_ip.pigsty_ip.subnet
}

output "meta_ip_ephemeral" {
  description = "Ephemeral public IP of pg-meta instance"
  value       = vultr_instance.pg-meta.main_ip
}

output "meta_private_ip" {
  description = "Private IP of pg-meta instance"
  value       = vultr_instance.pg-meta.internal_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${vultr_reserved_ip.pigsty_ip.subnet}"
}
