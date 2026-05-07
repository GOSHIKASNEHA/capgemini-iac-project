# -----------------------------------------------------------------------------
# Database Module — Input Variables
# -----------------------------------------------------------------------------
# These variables parameterise the RDS instance, subnet group, security group,
# and parameter group so the module can be reused across environments.
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
  description = "ID of the VPC where the database security group will be created."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group (minimum 2 in different AZs)."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets in different AZs are required for RDS."
  }
}

variable "allowed_security_group_ids" {
  description = <<-EOT
    List of security group IDs allowed to connect to the database (e.g. the
    compute module's SG). This is the preferred method over CIDR blocks because
    it ties access to specific resources, not IP ranges.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the database. Use security group IDs when possible."
  type        = list(string)
  default     = []
}

# ─── Engine ──────────────────────────────────────────────────────────────────

variable "engine" {
  description = "Database engine (e.g. mysql, postgres, mariadb)."
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "Database engine version (e.g. 8.0)."
  type        = string
  default     = "8.0"
}

variable "family" {
  description = "DB parameter group family (e.g. mysql8.0)."
  type        = string
  default     = "mysql8.0"
}

variable "port" {
  description = "Port number the database listens on."
  type        = number
  default     = 3306
}

# ─── Instance ────────────────────────────────────────────────────────────────

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.micro, db.r6g.large)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage allocation in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "Minimum storage for RDS is 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage in GiB for autoscaling. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "EBS storage type (gp3, gp2, io1)."
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Whether to encrypt the DB storage at rest."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of a custom KMS key for storage encryption. Uses AWS-managed key if empty."
  type        = string
  default     = ""
}

# ─── Authentication ──────────────────────────────────────────────────────────

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = "appdb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "db_username" {
  description = "Master username for the database. Avoid 'admin' or 'root' in production."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = !contains(["admin", "root", "administrator"], lower(var.db_username))
    error_message = "Do not use common usernames like admin, root, or administrator."
  }
}

variable "db_password" {
  description = <<-EOT
    Master password for the database. Must be at least 8 characters. In
    production, use AWS Secrets Manager and manage_master_user_password instead.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Password must be at least 8 characters."
  }
}

# ─── High Availability & Backups ─────────────────────────────────────────────

variable "multi_az" {
  description = "Enable Multi-AZ deployment for automatic failover."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0 to disable, max 35)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Preferred UTC time window for automated backups (e.g. 03:00-04:00)."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred UTC time window for maintenance (e.g. sun:05:00-sun:06:00)."
  type        = string
  default     = "sun:05:00-sun:06:00"
}

# ─── Protection ──────────────────────────────────────────────────────────────

variable "deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance via API/CLI/Terraform."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying. Set false in production."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Name of the final snapshot taken before deletion. Required when skip_final_snapshot is false."
  type        = string
  default     = ""
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

variable "performance_insights_enabled" {
  description = "Enable Performance Insights for query-level performance monitoring."
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0 to disable, or 1/5/10/15/30/60)."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60."
  }
}

# ─── Tags ────────────────────────────────────────────────────────────────────

variable "additional_tags" {
  description = "Map of additional tags to apply to every resource created by this module."
  type        = map(string)
  default     = {}
}
