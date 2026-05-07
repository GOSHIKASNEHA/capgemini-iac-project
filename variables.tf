# =============================================================================
# Root Configuration — Variables
# =============================================================================
# These variables are the top-level inputs for the entire infrastructure.
# They are passed through to individual modules via the root main.tf.
#
# Variable flow:
#   terraform.tfvars → variables.tf (this file) → main.tf → module inputs
#
# Each module also has its own variables.tf with additional module-specific
# inputs and validation rules. The root only exposes the variables that
# change between environments.
# =============================================================================


# ─── Global ──────────────────────────────────────────────────────────────────
# Shared identity variables consumed by every module for consistent naming
# and tagging (e.g. "capgemini-dev-vpc", "capgemini-prod-instance").

variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as a prefix for all resource Name tags."
  type        = string
  default     = "capgemini"
}

variable "environment" {
  description = "Deployment environment. Controls HA, deletion protection, and cost settings."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}


# ─── Networking ──────────────────────────────────────────────────────────────
# Passed to: module.networking
# Creates the VPC, subnets, IGW, NAT GW, and route tables.

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16 = 65,536 IPs)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of AZs for subnet placement (minimum 2 for high availability)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ. Hosts ALBs, NAT GW, bastion."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ. Hosts RDS, app servers."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway(s) for private subnet outbound access."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT GW (saves ~$32/mo) vs one per AZ (HA). Set false in prod."
  type        = bool
  default     = true
}


# ─── Compute ─────────────────────────────────────────────────────────────────
# Passed to: module.compute
# Creates the EC2 instance and its security group.

variable "instance_type" {
  description = "EC2 instance type (e.g. t2.micro, t3.small, m5.large)."
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair for SSH. Leave empty to disable key-based SSH."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB (gp3, encrypted)."
  type        = number
  default     = 20
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into the instance. Restrict to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


# ─── Database ────────────────────────────────────────────────────────────────
# Passed to: module.database
# Creates the RDS MySQL instance, security group, subnet group, and params.

variable "db_instance_class" {
  description = "RDS instance class (e.g. db.t3.micro, db.r6g.large)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB. Auto-scales up to max_allocated_storage."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the initial MySQL database to create."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the database. Avoid admin/root in production."
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for the database. Supply via -var or TF_VAR_db_password — never commit."
  type        = string
  sensitive   = true
}
