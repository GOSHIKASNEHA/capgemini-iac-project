# -----------------------------------------------------------------------------
# Compute Module — Local Values
# -----------------------------------------------------------------------------
# Centralises computed values and common tags so they are defined once and
# referenced consistently across all resources.
# -----------------------------------------------------------------------------

locals {
  # ── Naming prefix ─────────────────────────────────────────────────────────
  name_prefix = "${var.project_name}-${var.environment}"

  # ── AMI selection ─────────────────────────────────────────────────────────
  # Use the explicit AMI if provided; otherwise fall back to the data source
  # that looks up the latest Amazon Linux 2023 AMI.
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id

  # ── Common tags applied to every resource ─────────────────────────────────
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "compute"
    },
    var.additional_tags,
  )
}
