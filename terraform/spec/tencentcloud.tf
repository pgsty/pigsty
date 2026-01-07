#==============================================================#
# File      :   tencentcloud-meta.tf
# Desc      :   1-node pigsty meta for Tencent Cloud (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/tencentcloud-meta.tf
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

variable "region" {
  description = "Tencent Cloud region"
  type        = string
  default     = "ap-guangzhou"
}

variable "zone" {
  description = "Tencent Cloud availability zone"
  type        = string
  default     = "ap-guangzhou-7"
}

variable "password" {
  description = "Instance password"
  type        = string
  default     = "PigstyDemo4"
}

locals {
  bandwidth = 100  # internet bandwidth in Mbps
  disk_size = 40   # system disk size in GB

  # Instance types for Tencent Cloud
  # S5 for amd64, SR1 for arm64
  instance_type_map = {
    amd64 = "S5.MEDIUM4"    # 2 vCPU, 4 GiB
    arm64 = "SR1.MEDIUM4"   # 2 vCPU, 4 GiB (ARM)
  }

  # Image names for Debian
  # Use data source to query latest Debian images
  image_name_map = {
    amd64 = {
      d12 = "Debian Server 12"
      d13 = "Debian Server 13"
    }
    arm64 = {
      d12 = "Debian Server 12"
      d13 = "Debian Server 13"
    }
  }

  selected_instype   = local.instance_type_map[var.architecture]
  selected_image_name = local.image_name_map[var.architecture][var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "~> 1.81"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Add your credentials via environment variables:
# export TENCENTCLOUD_SECRET_ID="????????????????????"
# export TENCENTCLOUD_SECRET_KEY="????????????????????"
provider "tencentcloud" {
  region = var.region
}


#===========================================================#
# Data Sources
#===========================================================#
# Query available instance types
data "tencentcloud_instance_types" "default" {
  cpu_core_count   = 2
  memory_size      = 4
  exclude_sold_out = true

  filter {
    name   = "instance-charge-type"
    values = ["POSTPAID_BY_HOUR"]
  }
  filter {
    name   = "zone"
    values = [var.zone]
  }
}

# Query Debian images
data "tencentcloud_images" "debian" {
  image_type = ["PUBLIC_IMAGE"]
  os_name    = local.selected_image_name
}


#===========================================================#
# VPC
#===========================================================#
resource "tencentcloud_vpc" "pigsty_vpc" {
  name       = "pigsty-vpc"
  cidr_block = "10.10.10.0/24"
  tags = {
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Route Table
#===========================================================#
resource "tencentcloud_route_table" "pigsty_rt" {
  name   = "pigsty-rt"
  vpc_id = tencentcloud_vpc.pigsty_vpc.id
}


#===========================================================#
# Subnet
#===========================================================#
resource "tencentcloud_subnet" "pigsty_subnet" {
  name              = "pigsty-subnet"
  cidr_block        = "10.10.10.0/24"
  availability_zone = var.zone
  vpc_id            = tencentcloud_vpc.pigsty_vpc.id
  route_table_id    = tencentcloud_route_table.pigsty_rt.id
}


#===========================================================#
# Security Group
#===========================================================#
resource "tencentcloud_security_group" "pigsty_sg" {
  name        = "pigsty-sg"
  description = "Pigsty Security Group - Allow all traffic (demo only)"
}

resource "tencentcloud_security_group_lite_rule" "pigsty_sg_rule" {
  security_group_id = tencentcloud_security_group.pigsty_sg.id

  ingress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL"
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL"
  ]
}


#===========================================================#
# CVM Instance: pg-meta
#===========================================================#
resource "tencentcloud_instance" "pg-meta" {
  instance_name              = "pg-meta"
  hostname                   = "pg-meta"
  instance_type              = local.selected_instype
  availability_zone          = var.zone
  vpc_id                     = tencentcloud_vpc.pigsty_vpc.id
  subnet_id                  = tencentcloud_subnet.pigsty_subnet.id
  orderly_security_groups    = [tencentcloud_security_group.pigsty_sg.id]
  image_id                   = data.tencentcloud_images.debian.images.0.image_id
  password                   = var.password
  private_ip                 = "10.10.10.10"
  allocate_public_ip         = true
  internet_max_bandwidth_out = local.bandwidth

  system_disk_type = "CLOUD_PREMIUM"
  system_disk_size = local.disk_size

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
  value       = tencentcloud_instance.pg-meta.public_ip
}

output "ssh_command" {
  description = "SSH command to connect (use sshpass or ssh key)"
  value       = "sshpass -p ${var.password} ssh root@${tencentcloud_instance.pg-meta.public_ip}"
}
