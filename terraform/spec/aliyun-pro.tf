#==============================================================#
# File      :   aliyun-pro.yml
# Desc      :   5-node building env for x86_64/aarch64
# Ctime     :   2024-12-12
# Mtime     :   2025-12-15
# Path      :   terraform/spec/aliyun-pro.yml
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

locals {
  bandwidth = 100                       # internet bandwidth in Mbps (100Mbps)
  disk_size = 100                       # system disk size in GB (100GB)
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





#======================================#
# EL9 AMD64 / ARM64
#======================================#
data "alicloud_images" "el9_img" {
  owners     = "system"
  name_regex = local.selected_images.el9
}

resource "alicloud_instance" "pg-el9" {
  instance_name                 = "pg-el9"
  host_name                     = "pg-el9"
  private_ip                    = "10.10.10.9"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.el9_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = local.disk_size
}

output "el9_ip" {
  value = "${alicloud_instance.pg-el9.public_ip}"
}



#======================================#
# EL10 AMD64 / ARM64
#======================================#
data "alicloud_images" "el10_img" {
  owners     = "system"
  name_regex = local.selected_images.el10
}

resource "alicloud_instance" "pg-el10" {
  instance_name                 = "pg-el10"
  host_name                     = "pg-el10"
  private_ip                    = "10.10.10.10"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.el10_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = local.disk_size
}

output "el10_ip" {
  value = "${alicloud_instance.pg-el10.public_ip}"
}



#======================================#
# D12 AMD64 / ARM64
#======================================#
data "alicloud_images" "d12_img" {
  owners     = "system"
  name_regex = local.selected_images.d12
}

resource "alicloud_instance" "pg-d12" {
  instance_name                 = "pg-d12"
  host_name                     = "pg-d12"
  private_ip                    = "10.10.10.12"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.d12_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = local.disk_size
}

output "d12_ip" {
  value = "${alicloud_instance.pg-d12.public_ip}"
}



#======================================#
# D13 AMD64 / ARM64
#======================================#
data "alicloud_images" "d13_img" {
  owners     = "system"
  name_regex = local.selected_images.d13
}

resource "alicloud_instance" "pg-d13" {
  instance_name                 = "pg-d13"
  host_name                     = "pg-d13"
  private_ip                    = "10.10.10.13"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.d13_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = local.disk_size
}

output "d13_ip" {
  value = "${alicloud_instance.pg-d13.public_ip}"
}



#======================================#
# U22 ARM64
#======================================#
# ubuntu_22_04_arm64_20G_alibase_20230712.vhd
data "alicloud_images" "u22_img" {
  owners     = "system"
  name_regex = local.selected_images.u22
}

resource "alicloud_instance" "pg-u22" {
  instance_name                 = "pg-u22"
  host_name                     = "pg-u22"
  private_ip                    = "10.10.10.22"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.u22_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = local.disk_size
}

output "u22_ip" {
  value = "${alicloud_instance.pg-u22.public_ip}"
}



#======================================#
# U24 AMD64 / ARM64
#======================================#
data "alicloud_images" "u24_img" {
  owners     = "system"
  name_regex = local.selected_images.u24
}

resource "alicloud_instance" "pg-u24" {
  instance_name                 = "pg-u24"
  host_name                     = "pg-u24"
  private_ip                    = "10.10.10.24"
  instance_type                 = local.selected_instype
  image_id                      = "${data.alicloud_images.u24_img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = local.spot_policy
  spot_price_limit              = local.spot_price_limit
  internet_max_bandwidth_out    = local.bandwidth
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = local.disk_size
}

output "u24_ip" {
  value = "${alicloud_instance.pg-u24.public_ip}"
}

# sshpass -p PigstyDemo4 ssh-copy-id el8
# sshpass -p PigstyDemo4 ssh-copy-id el9
# sshpass -p PigstyDemo4 ssh-copy-id el10
# sshpass -p PigstyDemo4 ssh-copy-id d12
# sshpass -p PigstyDemo4 ssh-copy-id d13
# sshpass -p PigstyDemo4 ssh-copy-id u22
# sshpass -p PigstyDemo4 ssh-copy-id u24
