# -----------------------------------------------------------------------------
# Database Module — Local Values
# -----------------------------------------------------------------------------

locals {
  # ── Naming prefix ─────────────────────────────────────────────────────────
  name_prefix = "${var.project_name}-${var.environment}"

  # ── Final snapshot name ───────────────────────────────────────────────────
  # If the user doesn't supply a name, generate one from the prefix.
  final_snapshot_id = var.final_snapshot_identifier != "" ? var.final_snapshot_identifier : "${local.name_prefix}-db-final-snapshot"

  # ── Common tags applied to every resource ─────────────────────────────────
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "database"
    },
    var.additional_tags,
  )
}
