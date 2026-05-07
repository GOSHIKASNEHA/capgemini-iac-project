# Networking Module

Production-grade AWS VPC networking module for the Capgemini IaC project.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                   │
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────┐       │
│  │  Public Subnet AZ-a  │    │  Public Subnet AZ-b  │       │
│  │    10.0.1.0/24        │    │    10.0.2.0/24        │       │
│  │  ┌────────────────┐  │    │  ┌────────────────┐  │       │
│  │  │  NAT Gateway   │  │    │  │  NAT Gateway   │  │       │
│  │  └────────────────┘  │    │  └────────────────┘  │       │
│  └──────────┬───────────┘    └──────────┬───────────┘       │
│             │                           │                   │
│  ┌──────────▼───────────┐    ┌──────────▼───────────┐       │
│  │ Private Subnet AZ-a  │    │ Private Subnet AZ-b  │       │
│  │    10.0.10.0/24       │    │    10.0.20.0/24       │       │
│  └──────────────────────┘    └──────────────────────┘       │
│                                                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
               ┌──────▼──────┐
               │   Internet  │
               │   Gateway   │
               └─────────────┘
```

## Resources Created

| Resource                       | Count                       | Purpose                                       |
| ------------------------------ | --------------------------- | --------------------------------------------- |
| `aws_vpc`                      | 1                           | Isolated network boundary                     |
| `aws_internet_gateway`         | 1                           | Internet access for public subnets             |
| `aws_subnet` (public)          | N (one per AZ)              | Hosts ALBs, bastion hosts, NAT Gateways        |
| `aws_subnet` (private)         | N (one per AZ)              | Hosts apps, databases, internal services       |
| `aws_eip`                      | 0 / 1 / N                  | Static IP for NAT Gateway(s)                   |
| `aws_nat_gateway`              | 0 / 1 / N                  | Outbound internet for private subnets          |
| `aws_route_table` (public)     | 1                           | Routes public traffic via IGW                  |
| `aws_route_table` (private)    | 1 / N                      | Routes private traffic via NAT Gateway(s)      |
| `aws_route_table_association`  | 2N                          | Links every subnet to its route table          |

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  project_name = "capgemini"
  environment  = "prod"

  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false   # one NAT GW per AZ for HA

  additional_tags = {
    CostCenter = "infrastructure"
  }
}
```

## Inputs

| Name                      | Type           | Default         | Required | Description                                              |
| ------------------------- | -------------- | --------------- | -------- | -------------------------------------------------------- |
| `project_name`            | `string`       | —               | ✅        | Prefix for all resource names                            |
| `environment`             | `string`       | —               | ✅        | `dev`, `staging`, or `prod`                              |
| `vpc_cidr`                | `string`       | `10.0.0.0/16`   | No       | CIDR block for the VPC                                   |
| `availability_zones`      | `list(string)` | —               | ✅        | AZs to deploy into (min 2)                               |
| `public_subnet_cidrs`     | `list(string)` | —               | ✅        | CIDR blocks for public subnets                           |
| `private_subnet_cidrs`    | `list(string)` | —               | ✅        | CIDR blocks for private subnets                          |
| `enable_dns_support`      | `bool`         | `true`          | No       | Enable DNS resolution in VPC                             |
| `enable_dns_hostnames`    | `bool`         | `true`          | No       | Assign DNS hostnames to instances                        |
| `map_public_ip_on_launch` | `bool`         | `true`          | No       | Auto-assign public IPs in public subnets                 |
| `enable_nat_gateway`      | `bool`         | `true`          | No       | Provision NAT Gateway(s)                                 |
| `single_nat_gateway`      | `bool`         | `false`         | No       | Use a single shared NAT GW (cost optimisation)           |
| `additional_tags`         | `map(string)`  | `{}`            | No       | Extra tags for all resources                             |

## Outputs

| Name                      | Description                                     |
| ------------------------- | ----------------------------------------------- |
| `vpc_id`                  | ID of the VPC                                   |
| `vpc_cidr_block`          | CIDR block of the VPC                           |
| `vpc_arn`                 | ARN of the VPC                                  |
| `public_subnet_ids`       | List of public subnet IDs                       |
| `public_subnet_cidrs`     | List of public subnet CIDRs                     |
| `private_subnet_ids`      | List of private subnet IDs                      |
| `private_subnet_cidrs`    | List of private subnet CIDRs                    |
| `internet_gateway_id`     | ID of the Internet Gateway                      |
| `nat_gateway_ids`         | List of NAT Gateway IDs                         |
| `nat_gateway_public_ips`  | Elastic IPs of the NAT Gateways                 |
| `public_route_table_id`   | ID of the public route table                    |
| `private_route_table_ids` | List of private route table IDs                 |
| `availability_zones`      | AZs used by this stack                          |
