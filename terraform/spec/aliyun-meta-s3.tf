#==============================================================#
# File      :   aliyun-meta-s3.yml
# Desc      :   1-node sandbox env for x86_64/aarch64 with s3
# Ctime     :   2020-05-12
# Mtime     :   2024-11-19
# Path      :   terraform/spec/aliyun-meta-s3.yml
# License   :   AGPLv3 @ https://pgsty.com/docs/about/license
# Copyright :   2018-2025  Ruohang Feng / Vonng (rh@vonng.com)
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

variable "distro_code" {
  description = "The 3-char distro code (el8,el9,u22,u24,d12)"
  type        = string
  default     = "el9"       # el7/el8/el9/d11/d12/u20/u22/an8
}

locals {
  instance_type_map = {
      amd64 = "ecs.c8i.xlarge"   # 4c8g spot instance
      arm64 = "ecs.c8y.xlarge"   # 4c8g spot instance
  }
  image_regex_map = {
    amd64 = {
      el7   = "^centos_7_9_x64"
      el8   = "^rockylinux_8_10_x64"
      el9   = "^rockylinux_9_5_x64"
      d11   = "^debian_11_11_x64"
      d12   = "^debian_12_10_x64"
      u20   = "^ubuntu_20_04_x64"
      u22   = "^ubuntu_22_04_x64"
      u24   = "^ubuntu_24_04_x64"
      an8   = "^anolisos_8_9_x64"
    }
    arm64 = {
      el8   = "^rockylinux_8_10_arm64"
      el9   = "^rockylinux_9_5_arm64"
      d12   = "^debian_12_10_arm64"
      u22   = "^ubuntu_22_04_arm64"
      u24   = "^ubuntu_24_04_arm64"
    }
  }
  selected_instype = local.instance_type_map[var.architecture]                # node type: amd/arm
  selected_images = local.image_regex_map[var.architecture][var.distro_code]  # os: 5 distro x amd/arm
}

# the finally used image inquiry
data "alicloud_images" "img" {
  owners     = "system"
  name_regex = local.selected_images
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
  zone_id    = "cn-beijing-l"
}

# add default security group and allow all tcp traffic
resource "alicloud_security_group" "default" {
  name   = "default"
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
  image_id                      = "${data.alicloud_images.img.images.0.id}"
  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
  security_groups               = ["${alicloud_security_group.default.id}"]
  password                      = "PigstyDemo4"
  instance_charge_type          = "PostPaid"
  internet_charge_type          = "PayByTraffic"
  spot_strategy                 = "SpotAsPriceGo"
  internet_max_bandwidth_out    = 100
  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL1"
  system_disk_size              = 40
}


# print the public IP address after provisioning
output "public_ip" {
  value = "${alicloud_instance.pg-meta.public_ip}"
}

#resource "alicloud_instance" "pg-test-groups" {
#  for_each                      = toset(["1", "2", "3"])
#  instance_name                 = "pg-test-${each.key}"
#  host_name                     = "pg-test-${each.key}"
#  private_ip                    = "10.10.10.1${each.key}"
#  instance_type                 = local.selected_instype
#  image_id                      = "${data.alicloud_images.img.images.0.id}"
#  vswitch_id                    = "${alicloud_vswitch.vsw.id}"
#  security_groups               = ["${alicloud_security_group.default.id}"]
#  password                      = "PigstyDemo4"
#  instance_charge_type          = "PostPaid"
#  internet_charge_type          = "PayByTraffic"
#  spot_strategy                 = "SpotAsPriceGo"
#  system_disk_category          = "cloud_essd"
#  system_disk_performance_level = "PL1"
#  system_disk_size              = 40
#  #internet_max_bandwidth_out    = 100 # no public ip
#}

#===========================================================#
# The OSS bucket for PITR
#===========================================================#
resource "alicloud_oss_bucket" "pigsty-oss" {
  bucket = "pigsty-oss"
}

resource "alicloud_oss_bucket_acl" "pigsty-oss-acl" {
  bucket = alicloud_oss_bucket.pigsty-oss.bucket
  acl    = "private"
}

resource "alicloud_ram_user" "pigsty-oss-user" {
  name = "pigsty-oss-user"
  display_name = "pigsty-oss-rw-user"
}

resource "alicloud_ram_access_key" "pigsty-oss-key" {
  user_name = alicloud_ram_user.pigsty-oss-user.name
  secret_file = "~/pigsty.sk"
}
data "alicloud_caller_identity" "current" {}
resource "alicloud_ram_policy" "pigsty-oss-policy" {
  policy_name = "pigsty-oss-policy"
  description = "Policy for read/write access to Pigsty S3 bucket"
  policy_document = <<EOF
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "oss:*",
      "Resource": [
        "acs:oss:*:${data.alicloud_caller_identity.current.account_id}:${alicloud_oss_bucket.pigsty-oss.bucket}",
        "acs:oss:*:${data.alicloud_caller_identity.current.account_id}:${alicloud_oss_bucket.pigsty-oss.bucket}/*"
      ]
    }
  ]
}
EOF
}

resource "alicloud_ram_user_policy_attachment" "pigsty-oss-user-policy-bind" {
  user_name   = alicloud_ram_user.pigsty-oss-user.name
  policy_name = alicloud_ram_policy.pigsty-oss-policy.policy_name
  policy_type = "Custom" #alicloud_ram_policy.pigsty-oss-policy.type
}

output "pigsty-oss-ak" {
  value = alicloud_ram_access_key.pigsty-oss-key.user_name
}
