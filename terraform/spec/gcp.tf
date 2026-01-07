#==============================================================#
# File      :   gcp.tf
# Desc      :   1-node pigsty meta for Google Cloud (Debian 12/13)
# Ctime     :   2025-01-07
# Mtime     :   2025-01-07
# Path      :   terraform/spec/gcp.tf
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

variable "project" {
  description = "GCP project ID"
  type        = string
  # default   = "your-project-id"  # Set your project ID here or via env
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

locals {
  disk_size = 40  # system disk size in GB

  # Machine types: e2-medium for amd64, t2a-standard-2 for arm64
  machine_type_map = {
    amd64 = "e2-medium"        # 2 vCPU, 4 GiB (shared-core)
    arm64 = "t2a-standard-2"   # 2 vCPU, 8 GiB (Tau T2A Arm)
  }

  # Debian image families
  # Project: debian-cloud
  image_family_map = {
    amd64 = {
      d12 = "debian-12"
      d13 = "debian-13"
    }
    arm64 = {
      d12 = "debian-12-arm64"
      d13 = "debian-13-arm64"
    }
  }

  selected_machine_type = local.machine_type_map[var.architecture]
  selected_image_family = local.image_family_map[var.architecture][var.distro]
}


#===========================================================#
# Terraform Provider
#===========================================================#
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}


#===========================================================#
# Credentials
#===========================================================#
# Authenticate via gcloud CLI: gcloud auth application-default login
# Or use service account key:
# export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
# Or set credentials in provider block
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}


#===========================================================#
# VPC Network
#===========================================================#
resource "google_compute_network" "pigsty_vpc" {
  name                    = "pigsty-vpc"
  auto_create_subnetworks = false
}


#===========================================================#
# Subnet
#===========================================================#
resource "google_compute_subnetwork" "pigsty_subnet" {
  name          = "pigsty-subnet"
  ip_cidr_range = "10.10.10.0/24"
  region        = var.region
  network       = google_compute_network.pigsty_vpc.id

  private_ip_google_access = true
}


#===========================================================#
# Firewall Rules
#===========================================================#
# Allow all internal traffic within VPC
resource "google_compute_firewall" "pigsty_internal" {
  name    = "pigsty-allow-internal"
  network = google_compute_network.pigsty_vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.10.10.0/24"]
}

# Allow all external traffic (demo only - restrict in production!)
resource "google_compute_firewall" "pigsty_external" {
  name    = "pigsty-allow-external"
  network = google_compute_network.pigsty_vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["pigsty"]
}


#===========================================================#
# Static External IP
#===========================================================#
resource "google_compute_address" "pigsty_ip" {
  name   = "pigsty-ip"
  region = var.region
}


#===========================================================#
# Compute Instance: pg-meta
#===========================================================#
resource "google_compute_instance" "pg-meta" {
  name         = "pg-meta"
  machine_type = local.selected_machine_type
  zone         = var.zone

  tags = ["pigsty"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/${local.selected_image_family}"
      size  = local.disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.pigsty_subnet.self_link
    network_ip = "10.10.10.10"

    access_config {
      nat_ip = google_compute_address.pigsty_ip.address
    }
  }

  # Add SSH key metadata (replace with your public key)
  metadata = {
    ssh-keys = "pigsty:${file("~/.ssh/id_rsa.pub")}"
  }

  # Enable OS Login (alternative to SSH keys)
  # metadata = {
  #   enable-oslogin = "TRUE"
  # }

  labels = {
    name      = "pg-meta"
    project   = "pigsty"
    managedby = "terraform"
  }

  # Allow instance to be stopped for maintenance
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  # Service account (optional, uses default if not specified)
  service_account {
    scopes = ["cloud-platform"]
  }
}


#===========================================================#
# Output
#===========================================================#
output "meta_ip" {
  description = "Public IP of pg-meta instance"
  value       = google_compute_address.pigsty_ip.address
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/id_rsa pigsty@${google_compute_address.pigsty_ip.address}"
}

output "gcloud_ssh" {
  description = "Alternative: SSH via gcloud"
  value       = "gcloud compute ssh pg-meta --zone=${var.zone}"
}
