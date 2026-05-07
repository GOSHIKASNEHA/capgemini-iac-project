# -----------------------------------------------------------------------------
# Storage Module — Outputs
# -----------------------------------------------------------------------------
# Outputs expose key resource attributes so that other modules (compute,
# application, CI/CD pipelines) can reference this bucket without hard-coding
# identifiers.
# -----------------------------------------------------------------------------

# ─── Bucket ──────────────────────────────────────────────────────────────────

output "bucket_id" {
  description = "Name (ID) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name (e.g. bucket-name.s3.amazonaws.com)."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name (e.g. bucket-name.s3.us-east-1.amazonaws.com)."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "AWS region where the bucket is hosted."
  value       = aws_s3_bucket.this.region
}

# ─── Versioning ──────────────────────────────────────────────────────────────

output "versioning_status" {
  description = "Current versioning status (Enabled or Suspended)."
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

# ─── Encryption ──────────────────────────────────────────────────────────────

output "encryption_algorithm" {
  description = "Server-side encryption algorithm in use (aws:kms or AES256)."
  value       = var.sse_algorithm
}
