# -----------------------------------------------------------------------------
# Compute Module — Input Variables
# -----------------------------------------------------------------------------
# These variables parameterise the EC2 instance, security group, and key pair
# so the module can be reused across environments (dev, staging, prod).
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

# ─── Networking (injected from the networking module) ────────────────────────

variable "vpc_id" {
  description = "ID of the VPC where the instance and security group will be created."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to launch the EC2 instance in."
  type        = string
}

# ─── Instance ────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type (e.g. t2.micro, t3.small)."
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = <<-EOT
    AMI ID for the EC2 instance. If left empty, the module will automatically
    look up the latest Amazon Linux 2023 AMI in the current region.
  EOT
  type        = string
  default     = ""
}

variable "key_name" {
  description = <<-EOT
    Name of an existing EC2 Key Pair for SSH access. If left empty, SSH key-
    based login will not be configured (you can still use SSM Session Manager).
  EOT
  type        = string
  default     = ""
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP with the instance (set true for public subnets)."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "Root volume must be at least 8 GiB."
  }
}

variable "root_volume_type" {
  description = "EBS volume type for the root device (gp3, gp2, io1, etc.)."
  type        = string
  default     = "gp3"
}

variable "user_data" {
  description = "Shell script or cloud-init content to run at first boot."
  type        = string
  default     = ""
}

# ─── SSH Access ──────────────────────────────────────────────────────────────

variable "ssh_allowed_cidrs" {
  description = <<-EOT
    List of CIDR blocks permitted to SSH into the instance. Defaults to
    0.0.0.0/0 (open) — restrict this in production to your corporate IP range.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_port" {
  description = "Port number for SSH access."
  type        = number
  default     = 22
}

# ─── Tags ────────────────────────────────────────────────────────────────────

variable "additional_tags" {
  description = "Map of additional tags to apply to every resource created by this module."
  type        = map(string)
  default     = {}
}
