# Compute Module

Production-grade AWS EC2 compute module for the Capgemini IaC project.

## Architecture

```
                     Internet
                        │
                        ▼
              ┌─────────────────┐
              │ Internet Gateway │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │  Public Subnet   │
              │                  │
              │  ┌────────────┐  │
              │  │ EC2 Instance│  │  ← SSH (port 22) from allowed CIDRs
              │  │  t2.micro   │  │
              │  └──────┬─────┘  │
              │         │        │
              │  ┌──────▼─────┐  │
              │  │ Security   │  │  ← Ingress: SSH only
              │  │ Group      │  │  ← Egress: All traffic
              │  └────────────┘  │
              └──────────────────┘
```

## Security Hardening

| Feature | Setting | Why |
|---------|---------|-----|
| IMDSv2 | `http_tokens = "required"` | Prevents SSRF-based credential theft |
| EBS Encryption | `encrypted = true` | Data at rest compliance |
| Detailed Monitoring | `monitoring = true` | 1-minute CloudWatch metrics |
| Separate SG Rules | Individual `aws_security_group_rule` | Avoids SG replacement on rule change |
| SSH CIDR Restriction | Configurable `ssh_allowed_cidrs` | Limit access to known IPs |

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  project_name = "capgemini"
  environment  = "prod"

  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.public_subnet_ids[0]

  instance_type     = "t2.micro"
  key_name          = "my-ssh-key"
  ssh_allowed_cidrs = ["203.0.113.0/24"]  # Your corporate IP range

  root_volume_size = 30
  root_volume_type = "gp3"

  additional_tags = {
    CostCenter = "engineering"
    Role       = "web-server"
  }
}
```

## Inputs

| Name                  | Type           | Default         | Required | Description                                    |
| --------------------- | -------------- | --------------- | -------- | ---------------------------------------------- |
| `project_name`        | `string`       | —               | ✅        | Prefix for all resource names                  |
| `environment`         | `string`       | —               | ✅        | `dev`, `staging`, or `prod`                    |
| `vpc_id`              | `string`       | —               | ✅        | VPC to create resources in                     |
| `subnet_id`           | `string`       | —               | ✅        | Subnet to launch instance in                   |
| `instance_type`       | `string`       | `t2.micro`      | No       | EC2 instance type                              |
| `ami_id`              | `string`       | `""` (auto)     | No       | AMI ID (auto-selects Amazon Linux 2023)        |
| `key_name`            | `string`       | `""`            | No       | EC2 Key Pair name for SSH                      |
| `associate_public_ip` | `bool`         | `true`          | No       | Assign public IP                               |
| `root_volume_size`    | `number`       | `20`            | No       | Root EBS volume size in GiB                    |
| `root_volume_type`    | `string`       | `gp3`           | No       | Root EBS volume type                           |
| `user_data`           | `string`       | `""`            | No       | Bootstrap script                               |
| `ssh_allowed_cidrs`   | `list(string)` | `["0.0.0.0/0"]` | No       | CIDRs allowed to SSH in                        |
| `ssh_port`            | `number`       | `22`            | No       | SSH port number                                |
| `additional_tags`     | `map(string)`  | `{}`            | No       | Extra tags for all resources                   |

## Outputs

| Name                  | Description                                    |
| --------------------- | ---------------------------------------------- |
| `instance_id`         | ID of the EC2 instance                         |
| `instance_arn`        | ARN of the EC2 instance                        |
| `instance_public_ip`  | Public IPv4 address                            |
| `instance_private_ip` | Private IPv4 address                           |
| `instance_public_dns` | Public DNS hostname                            |
| `instance_private_dns`| Private DNS hostname                           |
| `instance_state`      | Current instance state                         |
| `security_group_id`   | ID of the security group                       |
| `security_group_arn`  | ARN of the security group                      |
| `security_group_name` | Name of the security group                     |
| `ami_id`              | Resolved AMI ID                                |
