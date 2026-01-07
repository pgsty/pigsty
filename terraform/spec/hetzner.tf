#==============================================================#
# File      :   hetzner.tf
# Desc      :   1-node pigsty meta for Hetzner Cloud (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/hetzner.tf
# Docs      :   https://pigsty.io/docs/deploy/terraform
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#


#===========================================================#
# Variables
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
  description = "Hetzner datacenter location"
  type        = string
  default     = "fsn1"     # fsn1 (Falkenstein), nbg1 (Nuremberg), hel1 (Helsinki), ash (Ashburn), hil (Hillsboro)
}

variable "network_zone" {
  description = "Hetzner network zone (eu-central for EU, us-east/us-west for US)"
  type        = string
  default     = "eu-central"  # eu-central, us-east, us-west
}

locals {
  # Hetzner server types
  # cx22: 2 vCPU (shared), 4GB RAM, 40GB SSD, ~$4.5/mo (best value!)
  # cx32: 4 vCPU (shared), 8GB RAM, 80GB SSD, ~$8/mo
  # cax21: 4 vCPU (ARM), 8GB RAM, 80GB SSD, ~$5.5/mo (ARM Ampere)
  server_type_map = {
    amd64 = "cx22"    # 2 vCPU, 4GB RAM, 40GB SSD
    arm64 = "cax21"   # 4 vCPU ARM, 8GB RAM, 80GB SSD
  }

  # Hetzner image names
  image_map = {
    d12 = "debian-12"
    d13 = "debian-13"
  }

  selected_server_type = local.server_type_map[var.architecture]
  selected_image       = local.image_map[var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Add your Hetzner API token via environment variable:
# export HCLOUD_TOKEN="????????????????????"
provider "hcloud" {
  # token = "????????????????????"
}


#===========================================================#
# SSH Key
#===========================================================#
resource "hcloud_ssh_key" "pigsty_key" {
  name       = "pigsty-key"
  public_key = file("~/.ssh/id_rsa.pub")
}


#===========================================================#
# Network (VPC equivalent)
#===========================================================#
resource "hcloud_network" "pigsty_net" {
  name     = "pigsty-net"
  ip_range = "10.10.0.0/16"
}

resource "hcloud_network_subnet" "pigsty_subnet" {
  network_id   = hcloud_network.pigsty_net.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = "10.10.10.0/24"
}


#===========================================================#
# Firewall
#===========================================================#
resource "hcloud_firewall" "pigsty_fw" {
  name = "pigsty-fw"

  # Allow all inbound (demo only - restrict in production!)
  rule {
    description = "Allow all TCP"
    direction   = "in"
    protocol    = "tcp"
    port        = "1-65535"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow all UDP"
    direction   = "in"
    protocol    = "udp"
    port        = "1-65535"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Outbound is allowed by default in Hetzner
}


#===========================================================#
# Primary IP (static public IP)
#===========================================================#
# Note: We let Hetzner auto-assign the IP in the same location as the server
# instead of specifying datacenter, which avoids datacenter naming issues


#===========================================================#
# Server: pg-meta
#===========================================================#
resource "hcloud_server" "pg-meta" {
  name         = "pg-meta"
  image        = local.selected_image
  server_type  = local.selected_server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.pigsty_key.id]
  firewall_ids = [hcloud_firewall.pigsty_fw.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.pigsty_net.id
    ip         = "10.10.10.10"
  }

  labels = {
    project = "pigsty"
    role    = "meta"
  }

  # Wait for network to be ready
  depends_on = [hcloud_network_subnet.pigsty_subnet]
}


#===========================================================#
# Output
#===========================================================#
output "meta_ip" {
  description = "Public IP of pg-meta server"
  value       = hcloud_server.pg-meta.ipv4_address
}

output "meta_private_ip" {
  description = "Private IP of pg-meta server"
  value       = "10.10.10.10"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${hcloud_server.pg-meta.ipv4_address}"
}
