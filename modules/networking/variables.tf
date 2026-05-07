# -----------------------------------------------------------------------------
# Networking Module — Input Variables
# -----------------------------------------------------------------------------
# These variables parameterise the VPC, subnets, and related networking
# resources so that the module can be reused across environments (dev, staging,
# prod) simply by changing variable values.
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used as a prefix for all resource Name tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod). Used in tags and naming."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "enable_dns_support" {
  description = "Whether to enable DNS resolution inside the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether to assign public DNS hostnames to instances with public IPs."
  type        = bool
  default     = true
}

# ─── Subnets ─────────────────────────────────────────────────────────────────

variable "availability_zones" {
  description = "List of Availability Zones in which to create subnets (e.g. [\"us-east-1a\", \"us-east-1b\"])."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two Availability Zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required."
  }
}

variable "map_public_ip_on_launch" {
  description = "Whether instances launched in public subnets receive a public IPv4 address."
  type        = bool
  default     = true
}

# ─── NAT Gateway ─────────────────────────────────────────────────────────────

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for private subnet internet access."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = <<-EOT
    If true, a single NAT Gateway is shared across all private subnets (lower
    cost). If false, one NAT Gateway is created per AZ (higher availability).
  EOT
  type        = bool
  default     = false
}

# ─── Tags ────────────────────────────────────────────────────────────────────

variable "additional_tags" {
  description = "Map of additional tags to apply to every resource created by this module."
  type        = map(string)
  default     = {}
}
