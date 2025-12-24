#==============================================================#
# File      :   aws-cn.yml
# Desc      :   1-node sandbox env on AWS China
# Ctime     :   2020-05-12
# Mtime     :   2024-11-19
# Path      :   terraform/spec/aws-cn.yml
# Docs      :   https://doc.pgsty.com/prepare/terraform
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#

###########################################################
# AWS Provider
###########################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
# export AWS_REGION="cn-north-1"
# export AWS_ACCESS_KEY_ID="xxxxxxxxxxx"
# export AWS_SECRET_ACCESS_KEY="xxxxxxx"

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                   = "cn-northwest-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "vscode"
}


###########################################################
# AWS Networking
###########################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc

#===============================#
# VPC
#===============================#
resource "aws_vpc" "pigsty_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "pigsty-vpc"
    Project     = "pigsty"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

#===============================#
# Subnet
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet
resource "aws_subnet" "pigsty_subnet" {
  vpc_id                  = aws_vpc.pigsty_vpc.id
  cidr_block              = "10.10.10.0/24"
  availability_zone       = "cn-northwest-1a"
  map_public_ip_on_launch = true
  tags = {
    Name        = "pigsty-subnet"
    Project     = "pigsty"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

#===============================#
# Internet Gateway
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "pigsty_igw" {
  vpc_id = aws_vpc.pigsty_vpc.id
  tags = {
    Name        = "pigsty-vpc"
    VPC         = aws_vpc.pigsty_vpc.id
    Project     = "pigsty"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

#===============================#
# Route Table
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "pigsty_rt" {
  vpc_id = aws_vpc.pigsty_vpc.id
  tags = {
    Name        = "pigsty-route"
    VPC         = aws_vpc.pigsty_vpc.id
    Project     = "pigsty"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

#===============================#
# Route
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.pigsty_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.pigsty_igw.id
}

#===============================#
# Route Table Association
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "pigsty_assoc" {
  subnet_id      = aws_subnet.pigsty_subnet.id
  route_table_id = aws_route_table.pigsty_rt.id
}




###########################################################
# AWS Security
###########################################################

#===============================#
## SSH KEY (REPLACE THIS!!!!)
#===============================#
# ssh-keygen -t rsa -N '' -f ~/.aws/pigsty-key

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
resource "aws_key_pair" "pigsty_key" {
  key_name   = "pigsty-key"
  public_key = file("~/.aws/pigsty-key.pub")
}

#===============================#
# SECURITY GROUP
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "pigsty_sg" {
  name        = "pigsty-sg"
  description = "Pigsty Security Group"
  vpc_id      = aws_vpc.pigsty_vpc.id
  tags = {
    Name        = "pigsty-sg"
    VPC         = aws_vpc.pigsty_vpc.id
    Project     = "pigsty"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

#===============================#
# SECURITY RULE
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule
resource "aws_security_group_rule" "public_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Public Access Out"
  security_group_id = aws_security_group.pigsty_sg.id
}

resource "aws_security_group_rule" "public_in" {
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  # TODO: LIMIT ACCESS WITH YOUR OWN CIDR BLOCKS!!!!
  # OTHERWISE ALL SERVICES WILL BE OPENED TO THE WORLD!!!!
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Public Access In"
  security_group_id = aws_security_group.pigsty_sg.id
}


###########################################################
# AWS EC2
###########################################################

#===============================#
# AWS EC2 INSTANCES (Pigsty Meta)
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "pigsty-meta" {
  ami                         = "ami-01cb2ecea35798f3f"
  instance_type               = "t2.micro"
  key_name                    = "pigsty-key"
  private_ip                  = "10.10.10.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.pigsty_sg.id]
  subnet_id                   = aws_subnet.pigsty_subnet.id
  #user_data                   = file("userdata.tpl")
  root_block_device {
    volume_size = 30
  }

  tags = {
    Name        = "Pigsty Meta Node"
    VPC         = aws_vpc.pigsty_vpc.id
    Project     = "pigsty"
    Environment = "dev"
    ManagedBy   = "terraform"
    cls         = "pigsty-meta"
    ins         = "pigsty-meta-1"
  }
}


#===============================#
# AWS Elastic IP: OUTPUT
#===============================#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip

resource "aws_eip" "pigsty-ip" {
  vpc = true
  instance                  = aws_instance.pigsty-meta.id
  associate_with_private_ip = "10.10.10.10"
  depends_on                = [aws_internet_gateway.pigsty_igw]
}

output "admin_ip" {
  value = aws_eip.pigsty-ip.public_ip
}
