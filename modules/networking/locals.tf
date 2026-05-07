# -----------------------------------------------------------------------------
# Networking Module — Local Values
# -----------------------------------------------------------------------------
# Centralises computed values and common tags so they are defined once and
# referenced consistently across all resources. This prevents tag drift and
# makes bulk changes trivial.
# -----------------------------------------------------------------------------

locals {
  # ── Naming prefix ─────────────────────────────────────────────────────────
  name_prefix = "${var.project_name}-${var.environment}"

  # ── Common tags applied to every resource ─────────────────────────────────
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "networking"
    },
    var.additional_tags,
  )

  # ── NAT Gateway count ────────────────────────────────────────────────────
  # When NAT is enabled we create either one gateway (cost‑optimised) or one
  # per AZ (high‑availability). When disabled, zero.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
}
