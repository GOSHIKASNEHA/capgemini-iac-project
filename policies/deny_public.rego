# =============================================================================
# Policy: Deny Public S3 Buckets
# =============================================================================
#
# This policy inspects the Terraform plan JSON and DENIES any S3 bucket that:
#
#   1. Has block_public_acls set to false (or missing)
#   2. Has block_public_policy set to false (or missing)
#   3. Has ignore_public_acls set to false (or missing)
#   4. Has restrict_public_buckets set to false (or missing)
#
# How to test:
#   terraform plan -out=tfplan.binary
#   terraform show -json tfplan.binary > tfplan.json
#   conftest test tfplan.json --policy policies/
#
# =============================================================================

package main

# ─── Helpers ─────────────────────────────────────────────────────────────────

s3_public_access_blocks[resource] {
	resource := input.resource_changes[_]
	resource.type == "aws_s3_bucket_public_access_block"
}

s3_buckets[resource] {
	resource := input.resource_changes[_]
	resource.type == "aws_s3_bucket"
	resource.change.actions[_] != "delete"
}

# ─── Rules ───────────────────────────────────────────────────────────────────

deny[msg] {
	resource := s3_public_access_blocks[_]
	not resource.change.after.block_public_acls
	msg := sprintf(
		"DENY: S3 public access block '%s' must have block_public_acls = true. Public ACLs allow anyone on the internet to read your data.",
		[resource.address],
	)
}

deny[msg] {
	resource := s3_public_access_blocks[_]
	not resource.change.after.block_public_policy
	msg := sprintf(
		"DENY: S3 public access block '%s' must have block_public_policy = true. A public bucket policy would expose all objects.",
		[resource.address],
	)
}

deny[msg] {
	resource := s3_public_access_blocks[_]
	not resource.change.after.ignore_public_acls
	msg := sprintf(
		"DENY: S3 public access block '%s' must have ignore_public_acls = true. Existing public ACLs must be neutralised.",
		[resource.address],
	)
}

deny[msg] {
	resource := s3_public_access_blocks[_]
	not resource.change.after.restrict_public_buckets
	msg := sprintf(
		"DENY: S3 public access block '%s' must have restrict_public_buckets = true. Unrestricted buckets can be accessed by any AWS account.",
		[resource.address],
	)
}

# Deny if buckets exist but no public access block resource is defined
deny[msg] {
	count(s3_buckets) > 0
	count(s3_public_access_blocks) == 0
	msg := "DENY: S3 bucket(s) detected but no aws_s3_bucket_public_access_block resource found. Every bucket must have public access explicitly blocked."
}
