#==============================================================#
# File      :   aws.tf
# Desc      :   1-node pigsty meta for AWS Global (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/aws.tf
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
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "availability_zone" {
  description = "AWS availability zone"
  type        = string
  default     = "us-west-2a"
}

locals {
  disk_size = 40  # system disk size in GB

  # Instance types: t3 for amd64, t4g for arm64 (Graviton)
  instance_type_map = {
    amd64 = "t3.medium"     # 2 vCPU, 4 GiB
    arm64 = "t4g.medium"    # 2 vCPU, 4 GiB (Graviton2)
  }

  # Debian AMI owner: 136693071363 (Debian official)
  # Use data source to find latest Debian AMI
  ami_name_map = {
    amd64 = {
      d12 = "debian-12-amd64-*"
      d13 = "debian-13-amd64-*"
    }
    arm64 = {
      d12 = "debian-12-arm64-*"
      d13 = "debian-13-arm64-*"
    }
  }

  selected_instype = local.instance_type_map[var.architecture]
  selected_ami_name = local.ami_name_map[var.architecture][var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Add your credentials via environment variables or AWS credentials file:
# export AWS_ACCESS_KEY_ID="????????????????????"
# export AWS_SECRET_ACCESS_KEY="????????????????????"
# export AWS_REGION="us-west-2"
#
# Or use ~/.aws/credentials file
provider "aws" {
  region = var.region
}


#===========================================================#
# SSH Key Pair
#===========================================================#
# Generate SSH key: ssh-keygen -t ed25519 -f ~/.ssh/pigsty-key -N ''
resource "aws_key_pair" "pigsty_key" {
  key_name   = "pigsty-key"
  public_key = file("~/.ssh/id_rsa.pub")  # or use your own key path
}


#===========================================================#
# AMI Data Source
#===========================================================#
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]  # Debian official

  filter {
    name   = "name"
    values = [local.selected_ami_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = [var.architecture == "amd64" ? "x86_64" : "arm64"]
  }
}


#===========================================================#
# VPC
#===========================================================#
resource "aws_vpc" "pigsty_vpc" {
  cidr_block           = "10.10.10.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name      = "pigsty-vpc"
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Subnet
#===========================================================#
resource "aws_subnet" "pigsty_subnet" {
  vpc_id                  = aws_vpc.pigsty_vpc.id
  cidr_block              = "10.10.10.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name      = "pigsty-subnet"
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Internet Gateway
#===========================================================#
resource "aws_internet_gateway" "pigsty_igw" {
  vpc_id = aws_vpc.pigsty_vpc.id
  tags = {
    Name      = "pigsty-igw"
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# Route Table
#===========================================================#
resource "aws_route_table" "pigsty_rt" {
  vpc_id = aws_vpc.pigsty_vpc.id
  tags = {
    Name      = "pigsty-rt"
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.pigsty_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.pigsty_igw.id
}

resource "aws_route_table_association" "pigsty_assoc" {
  subnet_id      = aws_subnet.pigsty_subnet.id
  route_table_id = aws_route_table.pigsty_rt.id
}


#===========================================================#
# Security Group
#===========================================================#
resource "aws_security_group" "pigsty_sg" {
  name        = "pigsty-sg"
  description = "Pigsty Security Group - Allow all traffic (demo only)"
  vpc_id      = aws_vpc.pigsty_vpc.id

  # Allow all inbound (restrict in production!)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound (demo only)"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name      = "pigsty-sg"
    Project   = "pigsty"
    ManagedBy = "terraform"
  }
}


#===========================================================#
# EC2 Instance: pg-meta
#===========================================================#
resource "aws_instance" "pg-meta" {
  ami                         = data.aws_ami.debian.id
  instance_type               = local.selected_instype
  key_name                    = aws_key_pair.pigsty_key.key_name
  private_ip                  = "10.10.10.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.pigsty_sg.id]
  subnet_id                   = aws_subnet.pigsty_subnet.id

  root_block_device {
    volume_size           = local.disk_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

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
  value       = aws_instance.pg-meta.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/id_rsa admin@${aws_instance.pg-meta.public_ip}"
}
