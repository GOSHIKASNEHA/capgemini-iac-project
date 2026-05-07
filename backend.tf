# =============================================================================
# Remote Backend Configuration — S3 + DynamoDB State Locking
# =============================================================================
#
# Terraform state is the single source of truth for your infrastructure.
# A remote backend solves three critical problems:
#
#   1. COLLABORATION — Team members share the same state file instead of
#      each having a local copy that drifts out of sync.
#
#   2. LOCKING — DynamoDB prevents two people from running `terraform apply`
#      at the same time, which would corrupt the state file.
#
#   3. DURABILITY — S3 provides 99.999999999% (11 nines) durability.
#      Combined with versioning, you can recover from any state corruption.
#
# Prerequisites (create these BEFORE running `terraform init`):
#
#   aws s3api create-bucket \
#     --bucket capgemini-terraform-state-ap-south-1 \
#     --region ap-south-1 \
#     --create-bucket-configuration LocationConstraint=ap-south-1
#
#   aws s3api put-bucket-versioning \
#     --bucket capgemini-terraform-state-ap-south-1 \
#     --versioning-configuration Status=Enabled
#
#   aws s3api put-bucket-encryption \
#     --bucket capgemini-terraform-state-ap-south-1 \
#     --server-side-encryption-configuration \
#       '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
#
#   aws s3api put-public-access-block \
#     --bucket capgemini-terraform-state-ap-south-1 \
#     --public-access-block-configuration \
#       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
#
#   aws dynamodb create-table \
#     --table-name capgemini-terraform-locks \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region ap-south-1
#
# =============================================================================

terraform {
  backend "s3" {


    key = "dev/capgemini/terraform.tfstate"
    dynamodb_table = "terraform-locks"

  }
}

# =============================================================================
    # ── S3 Bucket ────────────────────────────────────────────────────────────
    # The S3 bucket where the state file is stored. This bucket must already
    # exist — Terraform does NOT create it. Use a naming convention that
    # includes the region to avoid global name collisions.
    bucket = "capgemini-terraform-state-sneha"

    # ── State File Path ──────────────────────────────────────────────────────
    # The object key (file path) inside the bucket. Using a structured path
    # like "env/project/terraform.tfstate" allows multiple projects and
    # environments to share a single bucket without conflicts.
    #
    # Example layout:
    #   s3://capgemini-terraform-state-ap-south-1/
    #   ├── dev/capgemini/terraform.tfstate
    #   ├── staging/capgemini/terraform.tfstate
    #   └── prod/capgemini/terraform.tfstate

    # ── Region ───────────────────────────────────────────────────────────────
    # The AWS region where the S3 bucket and DynamoDB table live. This can
    # differ from the region where your infrastructure is deployed. Using
    # ap-south-1 (Mumbai) keeps state data within the Indian region for
    # data residency compliance.
    region = "ap-south-1"

    # ── Encryption ───────────────────────────────────────────────────────────
    # Encrypts the state file at rest using server-side encryption. The state
    # file contains ALL resource attributes, including sensitive values like
    # database passwords and private IPs. Encryption is non-negotiable.
    encrypt = true

    # ── DynamoDB State Locking ───────────────────────────────────────────────
    # The DynamoDB table used for state locking and consistency checking.
    # When someone runs `terraform plan` or `apply`, Terraform writes a lock
    # record to this table. If another user tries to run simultaneously,
    # they get an error:
    #
    #   "Error: Error locking state: ConditionalCheckFailedException"
    #
    # The table must have a primary key named "LockID" (String type).
    # PAY_PER_REQUEST billing means you only pay per lock operation (~$0.00/mo
    # for typical usage).
   
 
