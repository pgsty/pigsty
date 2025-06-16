# Terraform Templates

[Terraform](https://developer.hashicorp.com/terraform) is a popular IaC tool. You can create VMs on public cloud with one command.

Aliyun & AWS templates are used as example providers. You can modify `terraform.tf` file to use other cloud providers.

Check [Pigsty Docs: Terraform](https://pgsty.com/docs/prepare/terraform) for details.

## Specifications

* [spec/aliyun-meta.tf](spec/aliyun-meta.tf) : Aliyun 1 meta node template for all distro & amd/arm (default)  
* [spec/aliyun-full.tf](spec/aliyun-full.tf) : Aliyun 4-node sandbox template for all distro & amd/arm.
* [spec/aliyun-oss.tf](spec/aliyun-oss.tf) : Aliyun 5-node building template for all distro & amd/arm.
* [spec/aws-cn.tf](spec/aws-cn.tf) : AWS 4 node CentOS7 environment
* [spec/tencentcloud.tf](spec/tencentcloud.tf) : QCloud 4 node CentOS7 environment



## Quick Start

```bash
brew install terraform    # install via homebrew
terraform init            # install terraform provider: aliyun , aws, only required for the first time
terraform apply           # plan and apply: create VMs, etc...
```

Print public IP Address:

```bash
terraform output | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
```


## Aliyun Credential

You can add your aliyun credentials to the environment file, such as `~/.bash_profile`

```bash
export ALICLOUD_ACCESS_KEY="<your_access_key>"
export ALICLOUD_SECRET_KEY="<your_secret_key>"
export ALICLOUD_REGION="cn-beijing"
```


## AWS Credential

You have to set up aws config & credential to use AWS provider. 

```bash
# ~/.aws

# ~/.aws/config
[default]
region = cn-northwest-1

# ~/.aws/credentials
[default]
aws_access_key_id = <YOUR_AWS_ACCESS_KEY>
aws_secret_access_key =  <AWS_ACCESS_SECRET>

# ~/.aws/pigsty-key
# ~/.aws/pigsty-key.pub
```

