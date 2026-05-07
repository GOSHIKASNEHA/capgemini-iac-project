# -----------------------------------------------------------------------------
# Storage Module — Local Values
# -----------------------------------------------------------------------------
# Centralises computed values and common tags so they are defined once and
# referenced consistently across all resources.
# -----------------------------------------------------------------------------

# Look up the current AWS account ID for generating unique bucket names.
data "aws_caller_identity" "current" {}

locals {
  # ── Naming prefix ─────────────────────────────────────────────────────────
  name_prefix = "${var.project_name}-${var.environment}"

  # ── Bucket name ───────────────────────────────────────────────────────────
  # S3 bucket names must be globally unique. When the user doesn't supply a
  # name, we generate one using project + environment + account ID to avoid
  # collisions across AWS accounts.
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"

  # ── Common tags applied to every resource ─────────────────────────────────
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "storage"
    },
    var.additional_tags,
  )
}
