# Terraform Templates

[Terraform](https://developer.hashicorp.com/terraform) templates for provisioning cloud VMs to run Pigsty.

Docs: https://pigsty.io/docs/deploy/terraform

All templates create a single-node `pg-meta` instance with:
- **OS**: Debian 12 (default) or Debian 13
- **Arch**: amd64 (default) or arm64 (where supported)
- **Network**: VPC with `10.10.10.0/24` subnet, private IP `10.10.10.10`
- **Security**: All ports open (demo only - restrict in production!)



## Supported Cloud Providers

There are lots of cloud providers out there. Choose one that fits your needs.

| Provider         | Template                                | Instance Type                   | Monthly Cost | ARM Support |
|------------------|-----------------------------------------|---------------------------------|--------------|-------------|
| **Aliyun**       | [aliyun.tf](spec/aliyun.tf)             | ecs.c9i.large / ecs.c8y.large   | ~$20         | Yes         |
| **AWS**          | [aws.tf](spec/aws.tf)                   | t3.medium / t4g.medium          | ~$30         | Yes         |
| **Azure**        | [azure.tf](spec/azure.tf)               | Standard_B2s / Standard_B2ps_v2 | ~$30         | Yes         |
| **GCP**          | [gcp.tf](spec/gcp.tf)                   | e2-medium / t2a-standard-2      | ~$25         | Yes         |
| **Tencent**      | [tencentcloud.tf](spec/tencentcloud.tf) | S5.MEDIUM4 / SR1.MEDIUM4        | ~$20         | Yes         |
| **Hetzner**      | [hetzner.tf](spec/hetzner.tf)           | cx22 / cax21                    | **~$4.5**    | Yes         |
| **Vultr**        | [vultr.tf](spec/vultr.tf)               | vc2-2c-4gb                      | ~$20         | No          |
| **DigitalOcean** | [digitalocean.tf](spec/digitalocean.tf) | s-2vcpu-4gb                     | ~$24         | No          |
| **Linode**       | [linode.tf](spec/linode.tf)             | g6-standard-2                   | ~$24         | No          |

> **Best Value**: Hetzner offers the best price-performance ratio at ~$4.5/mo for 2 vCPU, 4GB RAM.

> Test & Build environment: pigsty is build with aliyun ECS x86/arm instances.


## Quick Start

### 1. Install Terraform

```bash
# macOS
brew install terraform

# Linux (Debian/Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### 2. Choose and Configure Template

```bash
cd ~/pigsty/terraform

# Copy your preferred template
cp spec/hetzner.tf terraform.tf      # Best value
# cp spec/aws.tf terraform.tf        # AWS Global
# cp spec/azure.tf terraform.tf      # Microsoft Azure
# cp spec/gcp.tf terraform.tf        # Google Cloud

# Edit variables if needed (distro, region, etc.)
vim terraform.tf
```

### 3. Set Credentials

```bash
# Example for Hetzner
export HCLOUD_TOKEN="your-api-token"

# See "Credentials" section below for other providers
```

### 4. Deploy

```bash
terraform init      # Download provider plugins (first time only)
terraform plan      # Preview changes
terraform apply     # Create resources (type 'yes' to confirm)
```

### 5. Get Server IP

```bash
terraform output meta_ip
# Or
terraform output ssh_command
```

### 6. Install Pigsty

```bash
# SSH into the server
ssh root@<server-ip>

# Install Pigsty
curl -fsSL https://repo.pigsty.io/get | bash
cd ~/pigsty
./bootstrap
./configure
./deploy.yml
```

### 7. Cleanup

```bash
terraform destroy   # Remove all resources (type 'yes' to confirm)
```



## Configuration Variables

Most templates support these variables:

| Variable       | Description                                            | Default |
|----------------|--------------------------------------------------------|---------|
| `distro`       | OS distribution (`d12` = Debian 12, `d13` = Debian 13) | `d12`   |
| `architecture` | CPU architecture (`amd64` or `arm64`)                  | `amd64` |
| `region`       | Cloud region/location                                  | Varies  |

Override via command line:
```bash
terraform apply -var="distro=d13" -var="architecture=arm64"
```

Or create a `terraform.tfvars` file:
```hcl
distro       = "d13"
architecture = "arm64"
region       = "us-west-2"
```



## Credentials

### Aliyun

```bash
export ALICLOUD_ACCESS_KEY="<your_access_key>"
export ALICLOUD_SECRET_KEY="<your_secret_key>"
export ALICLOUD_REGION="cn-shanghai"
```

### AWS

```bash
# Option 1: Environment variables
export AWS_ACCESS_KEY_ID="<your_access_key>"
export AWS_SECRET_ACCESS_KEY="<your_secret_key>"
export AWS_REGION="us-west-2"

# Option 2: AWS credentials file (~/.aws/credentials)
[default]
aws_access_key_id = <YOUR_AWS_ACCESS_KEY>
aws_secret_access_key = <AWS_ACCESS_SECRET>
```

### Azure

```bash
# Option 1: Azure CLI (recommended)
az login

# Option 2: Service Principal
export ARM_CLIENT_ID="<your_client_id>"
export ARM_CLIENT_SECRET="<your_client_secret>"
export ARM_SUBSCRIPTION_ID="<your_subscription_id>"
export ARM_TENANT_ID="<your_tenant_id>"
```

### GCP

```bash
# Option 1: gcloud CLI (recommended)
gcloud auth application-default login

# Option 2: Service Account
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# Note: GCP requires project ID - set in terraform.tf or:
terraform apply -var="project=your-project-id"
```

### Tencent Cloud

```bash
export TENCENTCLOUD_SECRET_ID="<your_secret_id>"
export TENCENTCLOUD_SECRET_KEY="<your_secret_key>"
```

### Hetzner

```bash
export HCLOUD_TOKEN="<your_api_token>"
```
Get token from: https://console.hetzner.cloud → Project → Security → API tokens

### Vultr

```bash
export VULTR_API_KEY="<your_api_key>"
```
Get API key from: https://my.vultr.com/settings/#settingsapi

### DigitalOcean

```bash
export DIGITALOCEAN_TOKEN="<your_api_token>"
```
Get token from: https://cloud.digitalocean.com/account/api/tokens

### Linode

```bash
export LINODE_TOKEN="<your_api_token>"
```
Get token from: https://cloud.linode.com/profile/tokens



## SSH Key Setup

All templates expect an SSH public key at `~/.ssh/id_rsa.pub`. Generate one if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_rsa -N ''
```

To use a different key, edit the template:
```hcl
public_key = file("~/.ssh/your-key.pub")
```



## Security Warning

**These templates are for demo/development only!**

All security groups/firewalls are configured to allow all traffic from anywhere (`0.0.0.0/0`). For production:

1. Restrict inbound rules to your IP or CIDR blocks
2. Use SSH keys only, disable password authentication
3. Enable cloud provider's security features (WAF, DDoS protection, etc.)
4. Review Pigsty's [security documentation](https://pigsty.io/docs/security/)



## Troubleshooting

### SSH Connection Issues

```bash
# Check if server is reachable
ping $(terraform output -raw meta_ip)

# Check SSH with verbose output
ssh -v root@$(terraform output -raw meta_ip)

# Verify SSH key
ssh-add -l
```

### Terraform State Issues

```bash
# Refresh state
terraform refresh

# Force recreate
terraform taint <resource_name>
terraform apply
```

### Provider Plugin Issues

```bash
# Clear and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```



## All Templates

### Global Regions
* [spec/aws.tf](spec/aws.tf) - AWS Global regions
* [spec/azure.tf](spec/azure.tf) - Microsoft Azure
* [spec/gcp.tf](spec/gcp.tf) - Google Cloud Platform
* [spec/hetzner.tf](spec/hetzner.tf) - Hetzner Cloud (best value)
* [spec/vultr.tf](spec/vultr.tf) - Vultr
* [spec/digitalocean.tf](spec/digitalocean.tf) - DigitalOcean
* [spec/linode.tf](spec/linode.tf) - Linode/Akamai

### China Regions
* [spec/aliyun.tf](spec/aliyun.tf) - Aliyun single node (all distros, amd64/arm64)
* [spec/aliyun-s3.tf](spec/aliyun-s3.tf) - Aliyun single node with OSS/S3 bucket for PITR
* [spec/aliyun-full.tf](spec/aliyun-full.tf) - Aliyun 4-node sandbox
* [spec/aliyun-pro.tf](spec/aliyun-pro.tf) - Aliyun multi-distro build environment
* [spec/tencentcloud.tf](spec/tencentcloud.tf) - Tencent Cloud single node
* [spec/aws-cn.tf](spec/aws-cn.tf) - AWS China region
