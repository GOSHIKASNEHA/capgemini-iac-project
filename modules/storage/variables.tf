# -----------------------------------------------------------------------------
# Storage Module — Input Variables
# -----------------------------------------------------------------------------
# These variables parameterise the S3 bucket and its security configuration
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

# ─── Bucket ──────────────────────────────────────────────────────────────────

variable "bucket_name" {
  description = <<-EOT
    Globally unique S3 bucket name. If left empty, a name is generated from
    project_name, environment, and AWS account ID.
  EOT
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = <<-EOT
    If true, all objects (including locked ones) are deleted when the bucket is
    destroyed. Set to true only in dev/test — NEVER in production.
  EOT
  type        = bool
  default     = false
}

# ─── Versioning ──────────────────────────────────────────────────────────────

variable "enable_versioning" {
  description = "Enable S3 object versioning. Protects against accidental deletes and overwrites."
  type        = bool
  default     = true
}

# ─── Encryption ──────────────────────────────────────────────────────────────

variable "sse_algorithm" {
  description = "Server-side encryption algorithm. Use 'aws:kms' for KMS or 'AES256' for SSE-S3."
  type        = string
  default     = "aws:kms"

  validation {
    condition     = contains(["aws:kms", "AES256"], var.sse_algorithm)
    error_message = "sse_algorithm must be 'aws:kms' or 'AES256'."
  }
}

variable "kms_key_arn" {
  description = <<-EOT
    ARN of a custom KMS key for server-side encryption. If empty, the AWS
    managed key (aws/s3) is used. Only applies when sse_algorithm is 'aws:kms'.
  EOT
  type        = string
  default     = ""
}

# ─── Lifecycle ───────────────────────────────────────────────────────────────

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules to transition/expire objects and reduce storage costs."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after which non-current object versions are permanently deleted."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "Must be at least 1 day."
  }
}

variable "noncurrent_version_transition_days" {
  description = "Number of days after which non-current versions move to GLACIER."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_transition_days >= 1
    error_message = "Must be at least 1 day."
  }
}

# ─── Access Logging ──────────────────────────────────────────────────────────

variable "enable_access_logging" {
  description = "Enable S3 server access logging to a target bucket."
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Name of the S3 bucket to receive access logs. Required when enable_access_logging is true."
  type        = string
  default     = ""
}

variable "logging_target_prefix" {
  description = "Prefix (folder) inside the logging bucket for access log files."
  type        = string
  default     = "s3-access-logs/"
}

# ─── Tags ────────────────────────────────────────────────────────────────────

variable "additional_tags" {
  description = "Map of additional tags to apply to every resource created by this module."
  type        = map(string)
  default     = {}
}
