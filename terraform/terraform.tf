#==============================================================#
# File      :   terraform.yml
# Desc      :   1-node cloud vm env for x86_64/aarch64
# Ctime     :   2020-05-12
# Mtime     :   2025-12-15
# Path      :   terraform/terraform.yml
# Docs      :   https://doc.pgsty.com/prepare/terraform
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#


#===========================================================#
# Architecture, Instance Type, OS Images
#===========================================================#
variable "architecture" {
  description = "The architecture type (amd64 or arm64), choose one from them"
  type        = string
  default     = "amd64"    # comment this to use arm64
  #default     = "arm64"   # uncomment this to use arm64
}

variable "distro" {
  description = "The distro code (el8,el9,u22,u24,d12,d13)"
  type        = string
  default     = "el9"       # el7/el8/el9/el10/d11/d12/d13/u20/u22/an8
}

locals {
  bandwidth = 100                       # internet bandwidth in Mbps (100Mbps)
  disk_size = 40                        # system disk size in GB (40GB)
  spot_policy = "SpotWithPriceLimit"    # NoSpot, SpotWithPriceLimit, SpotAsPriceGo
  spot_price_limit = 5                  # only valid when spot_policy is SpotWithPriceLimit
  instance_type_map = {
    amd64 = "ecs.c9i.large"
    arm64 = "ecs.c8y.large"
  }
  image_regex_map = {
    amd64 = {
      el7   = "^centos_7_9_x64"
      el8   = "^rockylinux_8_10_x64"
      el9   = "^rockylinux_9_6_x64"
      el10  = "^rockylinux_10_0_x64"
      d11   = "^debian_11_11_x64"
      d12   = "^debian_12_11_x64"
      d13   = "^debian_13_1_x64"
      u20   = "^ubuntu_20_04_x64"
      u22   = "^ubuntu_22_04_x64"
      u24   = "^ubuntu_24_04_x64"
      an8   = "^anolisos_8_9_x64"
      al3   = "^aliyun_3_0_x64"
    }
    arm64 = {
      el8   = "^rockylinux_8_10_arm64"
      el9   = "^rockylinux_9_6_arm64"
      el10   = "^rockylinux_10_0_arm64"
      d12   = "^debian_12_11_arm64"
      d13   = "^debian_13_1_arm64"
      u22   = "^ubuntu_22_04_arm64"
      u24   = "^ubuntu_24_04_arm64"
    }
  }
  selected_images = local.image_regex_map[var.architecture]
  selected_instype = local.instance_type_map[var.architecture]
}

data "alicloud_images" "pigsty_img" {
  owners     = "system"
  name_regex = local.selected_images[var.distro]
}

#===========================================================#
# Credentials
#===========================================================#
# add your credentials here or pass them via env
# export ALICLOUD_ACCESS_KEY="????????????????????"
# export ALICLOUD_SECRET_KEY="????????????????????"
# e.g : ./aliyun-key.sh
provider "alicloud" {
  # access_key = "????????????????????"
  # secret_key = "????????????????????"
  region = "cn-shanghai"
}


#===========================================================#
# VPC, SWITCH, SECURITY GROUP
#===========================================================#
# use 10.10.10.0/24 cidr block as demo network
resource "alicloud_vpc" "vpc" {
  vpc_name   = "pigsty-net"
  cidr_block = "10.10.10.0/24"
}

# add virtual switch for pigsty demo network
resource "alicloud_vswitch" "vsw" {
  vpc_id     = "${alicloud_vpc.vpc.id}"
  cidr_block = "10.10.10.0/24"
  zone_id    = "cn-shanghai-l"
}

# add default security group and allow all tcp traffic
resource "alicloud_security_group" "default" {
  security_group_name = "default"
  vpc_id = "${alicloud_vpc.vpc.id}"
}
resource "alicloud_security_group_rule" "allow_all_tcp" {
  ip_protocol       = "tcp"
  type              = "ingress"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = "${alicloud_security_group.default.id}"
  cidr_ip           = "0.0.0.0/0"
}

#===========================================================#
# The meta node: pg-meta instance
#===========================================================#
resource "alicloud_instance" "pg-meta" {
  instance_name                 = "pg-meta"
  host_name                     = "pg-meta"
  private_ip                    = "10.10.10.10"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.pigsty_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_size              = local.disk_size
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
}

# print the meta IP address after provisioning
output "meta_ip" {
  value = "${alicloud_instance.pg-meta.public_ip}"
}
