#==============================================================#
# File      :   digitalocean.tf
# Desc      :   1-node pigsty meta for DigitalOcean (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/digitalocean.tf
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
  description = "DigitalOcean region"
  type        = string
  default     = "sfo3"     # nyc1, nyc3, sfo3, ams3, sgp1, lon1, fra1, tor1, blr1
}

locals {
  # Droplet sizes
  # s-1vcpu-1gb: 1 vCPU, 1GB RAM, 25GB SSD, $6/mo
  # s-1vcpu-2gb: 1 vCPU, 2GB RAM, 50GB SSD, $12/mo
  # s-2vcpu-4gb: 2 vCPU, 4GB RAM, 80GB SSD, $24/mo
  droplet_size = "s-2vcpu-4gb"  # 2 vCPU, 4GB RAM

  # DigitalOcean image slugs
  image_map = {
    d12 = "debian-12-x64"
    d13 = "debian-13-x64"
  }

  selected_image = local.image_map[var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Add your DigitalOcean API token via environment variable:
# export DIGITALOCEAN_TOKEN="????????????????????"
provider "digitalocean" {
  # token = "????????????????????"
}


#===========================================================#
# SSH Key
#===========================================================#
resource "digitalocean_ssh_key" "pigsty_key" {
  name       = "pigsty-key"
  public_key = file("~/.ssh/id_rsa.pub")
}


#===========================================================#
# VPC
#===========================================================#
resource "digitalocean_vpc" "pigsty_vpc" {
  name     = "pigsty-vpc"
  region   = var.region
  ip_range = "10.10.0.0/16"  # DigitalOcean auto-assigns private IPs from this range
}


#===========================================================#
# Firewall
#===========================================================#
resource "digitalocean_firewall" "pigsty_fw" {
  name = "pigsty-fw"

  droplet_ids = [digitalocean_droplet.pg-meta.id]

  # Allow all inbound (demo only - restrict in production!)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "1-65535"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "1-65535"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}


#===========================================================#
# Reserved IP (optional, for static public IP)
#===========================================================#
resource "digitalocean_reserved_ip" "pigsty_ip" {
  droplet_id = digitalocean_droplet.pg-meta.id
  region     = var.region
}


#===========================================================#
# Droplet: pg-meta
#===========================================================#
resource "digitalocean_droplet" "pg-meta" {
  name     = "pg-meta"
  image    = local.selected_image
  region   = var.region
  size     = local.droplet_size
  vpc_uuid = digitalocean_vpc.pigsty_vpc.id
  ssh_keys = [digitalocean_ssh_key.pigsty_key.fingerprint]

  # Enable private networking
  ipv6 = true

  tags = ["pigsty", "pg-meta"]
}


#===========================================================#
# Output
#===========================================================#
output "meta_ip" {
  description = "Public IP of pg-meta droplet (reserved)"
  value       = digitalocean_reserved_ip.pigsty_ip.ip_address
}

output "meta_ip_ephemeral" {
  description = "Ephemeral public IP of pg-meta droplet"
  value       = digitalocean_droplet.pg-meta.ipv4_address
}

output "meta_private_ip" {
  description = "Private IP of pg-meta droplet"
  value       = digitalocean_droplet.pg-meta.ipv4_address_private
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${digitalocean_reserved_ip.pigsty_ip.ip_address}"
}
