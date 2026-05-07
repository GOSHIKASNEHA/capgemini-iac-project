# =============================================================================
# Storage Module — Main Resources
# =============================================================================
# This module provisions a production-hardened AWS S3 bucket with:
#
#   • Private-by-default access (Block Public Access on all four axes)
#   • Object versioning for data protection
#   • Server-side encryption (SSE-KMS or SSE-S3)
#   • Bucket policy enforcing encryption in transit (HTTPS only)
#   • Lifecycle rules to transition old versions to Glacier and expire them
#   • Optional server access logging
#   • Consistent tagging via `local.common_tags`
#
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# 1. S3 Bucket
# ─────────────────────────────────────────────────────────────────────────────
# The core storage resource. In the modern AWS provider (v4+), most bucket
# features are configured via dedicated sub-resources (versioning, encryption,
# etc.) rather than inline blocks. This gives Terraform finer-grained control
# over each setting and avoids full-bucket replacement on config changes.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })
}


# ─────────────────────────────────────────────────────────────────────────────
# 2. Block Public Access
# ─────────────────────────────────────────────────────────────────────────────
# This is the MOST CRITICAL security control for S3. It acts as an account-
# level override that prevents any ACL or bucket policy from accidentally
# making the bucket public — even if someone misconfigures a policy later.
#
# All four settings are set to `true`:
#   • block_public_acls       — rejects PUT requests with public ACLs
#   • ignore_public_acls      — ignores existing public ACLs
#   • block_public_policy     — rejects bucket policies that grant public access
#   • restrict_public_buckets — restricts access to AWS principals only
#
# SECURITY: This is a defense-in-depth measure. Even with correct policies,
# enabling this prevents human error from creating a public data exposure.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ─────────────────────────────────────────────────────────────────────────────
# 3. Bucket Ownership Controls
# ─────────────────────────────────────────────────────────────────────────────
# Enforces "BucketOwnerEnforced" — ACLs are disabled entirely and the bucket
# owner automatically owns all objects, regardless of who uploaded them. This
# is the AWS-recommended setting and simplifies access management by making
# bucket policies the single source of truth.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  depends_on = [aws_s3_bucket_public_access_block.this]
}


# ─────────────────────────────────────────────────────────────────────────────
# 4. Versioning
# ─────────────────────────────────────────────────────────────────────────────
# Object versioning preserves every version of every object. When enabled:
#   • Accidental deletes create a "delete marker" — the data is recoverable
#   • Accidental overwrites keep the previous version alongside the new one
#   • Combined with lifecycle rules, old versions auto-expire to control costs
#
# SECURITY: Versioning is a key defence against ransomware — encrypted/
# corrupted objects can be rolled back to a clean prior version.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# 5. Server-Side Encryption
# ─────────────────────────────────────────────────────────────────────────────
# Encrypts all objects at rest. Two options:
#
#   • SSE-S3 (AES256) — AWS manages the key, zero config, no extra cost.
#   • SSE-KMS (aws:kms) — Uses AWS KMS. Adds audit trail via CloudTrail,
#     supports key rotation policies, and allows fine-grained key permissions.
#
# The `bucket_key_enabled` flag reduces KMS API calls (and cost) by generating
# a per-bucket data key instead of calling KMS for every single object.
#
# SECURITY: S3 now encrypts all new objects by default (since Jan 2023), but
# explicitly setting the configuration ensures it cannot be changed and makes
# the intent clear in code.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" && var.kms_key_arn != "" ? var.kms_key_arn : null
    }

    bucket_key_enabled = var.sse_algorithm == "aws:kms" ? true : false
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# 6. Bucket Policy — Enforce HTTPS (Encryption in Transit)
# ─────────────────────────────────────────────────────────────────────────────
# This policy denies ALL requests made over plain HTTP (non-TLS). Combined
# with server-side encryption (at rest), this gives you full encryption
# coverage — data is protected both in transit and at rest.
#
# The condition `aws:SecureTransport = false` catches any request that wasn't
# made over HTTPS. This is an AWS and CIS Benchmark best practice.
#
# SECURITY: Without this policy, someone could accidentally use an HTTP
# endpoint and transmit data in cleartext over the network.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "EnforceTLSPolicy"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}


# ─────────────────────────────────────────────────────────────────────────────
# 7. Lifecycle Rules
# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle rules automate storage cost management:
#
#   Rule 1 — After N days, non-current versions move to Glacier (cheap cold
#            storage at ~$0.004/GB vs $0.023/GB for Standard).
#   Rule 2 — After M days, non-current versions are permanently deleted.
#
# This prevents version history from growing unboundedly and consuming budget.
#
# Example with defaults (30/90 days):
#   Day 0:  Object v2 uploaded (v1 becomes non-current)
#   Day 30: v1 moves to Glacier
#   Day 90: v1 is permanently deleted
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-noncurrent-to-glacier"
    status = "Enabled"

    filter {} # applies to all objects

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "GLACIER"
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {} # applies to all objects

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}


# ─────────────────────────────────────────────────────────────────────────────
# 8. Server Access Logging (Optional)
# ─────────────────────────────────────────────────────────────────────────────
# Records detailed logs for every request made to this bucket — who accessed
# what, when, and from where. Logs are written to a separate target bucket.
#
# SECURITY: Access logging is essential for:
#   • Forensic analysis after a security incident
#   • Compliance auditing (PCI-DSS, HIPAA, SOC2)
#   • Identifying unusual access patterns (exfiltration, brute-force)
#
# Note: The target bucket must have appropriate ACL/policy to receive logs.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_logging" "this" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix
}
