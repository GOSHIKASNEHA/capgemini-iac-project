# Storage Module

Production-hardened AWS S3 storage module for the Capgemini IaC project.

## Security Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          S3 Bucket                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Layer 1: Block Public Access (all 4 flags = true)          │ │
│  │  → Prevents ANY public access, even from misconfigured ACLs │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Layer 2: Bucket Policy (HTTPS only)                        │ │
│  │  → Denies all non-TLS requests — encryption in transit      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Layer 3: Server-Side Encryption (SSE-KMS / SSE-S3)         │ │
│  │  → All objects encrypted at rest automatically              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Layer 4: Versioning                                        │ │
│  │  → Protects against accidental deletes and ransomware       │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Layer 5: Lifecycle Rules                                   │ │
│  │  → Old versions → Glacier (30d) → Deleted (90d)            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Layer 6: Access Logging (optional)                         │ │
│  │  → Audit trail for compliance and forensics                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## Resources Created

| Resource                                          | Count | Purpose                                    |
| ------------------------------------------------- | ----- | ------------------------------------------ |
| `aws_s3_bucket`                                   | 1     | The storage container                      |
| `aws_s3_bucket_public_access_block`               | 1     | Blocks all public access                   |
| `aws_s3_bucket_ownership_controls`                | 1     | Disables ACLs, bucket owner owns all       |
| `aws_s3_bucket_versioning`                        | 1     | Enables/suspends object versioning         |
| `aws_s3_bucket_server_side_encryption_configuration` | 1  | Configures at-rest encryption              |
| `aws_s3_bucket_policy`                            | 1     | Enforces HTTPS-only access                 |
| `aws_s3_bucket_lifecycle_configuration`           | 0/1   | Manages old version storage costs          |
| `aws_s3_bucket_logging`                           | 0/1   | Writes access logs to target bucket        |

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  project_name = "capgemini"
  environment  = "prod"

  # Optional overrides
  enable_versioning   = true
  sse_algorithm       = "aws:kms"
  force_destroy       = false

  enable_lifecycle_rules              = true
  noncurrent_version_transition_days  = 30
  noncurrent_version_expiration_days  = 90

  additional_tags = {
    CostCenter  = "infrastructure"
    DataClass   = "confidential"
  }
}
```

## Inputs

| Name                                 | Type          | Default     | Required | Description                                    |
| ------------------------------------ | ------------- | ----------- | -------- | ---------------------------------------------- |
| `project_name`                       | `string`      | —           | ✅        | Prefix for resource names                      |
| `environment`                        | `string`      | —           | ✅        | `dev`, `staging`, or `prod`                    |
| `bucket_name`                        | `string`      | `""` (auto) | No       | Custom bucket name (auto-generated if empty)   |
| `force_destroy`                      | `bool`        | `false`     | No       | Delete all objects on bucket destroy           |
| `enable_versioning`                  | `bool`        | `true`      | No       | Enable object versioning                       |
| `sse_algorithm`                      | `string`      | `aws:kms`   | No       | `aws:kms` or `AES256`                          |
| `kms_key_arn`                        | `string`      | `""`        | No       | Custom KMS key ARN                             |
| `enable_lifecycle_rules`             | `bool`        | `true`      | No       | Enable lifecycle management                    |
| `noncurrent_version_transition_days` | `number`      | `30`        | No       | Days before old versions → Glacier             |
| `noncurrent_version_expiration_days` | `number`      | `90`        | No       | Days before old versions are deleted            |
| `enable_access_logging`              | `bool`        | `false`     | No       | Enable server access logging                   |
| `logging_target_bucket`              | `string`      | `""`        | No       | Target bucket for access logs                  |
| `logging_target_prefix`              | `string`      | `s3-access-logs/` | No | Log file prefix                               |
| `additional_tags`                    | `map(string)` | `{}`        | No       | Extra tags                                     |

## Outputs

| Name                            | Description                         |
| ------------------------------- | ----------------------------------- |
| `bucket_id`                     | Bucket name                         |
| `bucket_arn`                    | Bucket ARN                          |
| `bucket_domain_name`            | Global S3 domain name               |
| `bucket_regional_domain_name`   | Regional S3 domain name             |
| `bucket_region`                 | AWS region of the bucket            |
| `versioning_status`             | `Enabled` or `Suspended`            |
| `encryption_algorithm`          | `aws:kms` or `AES256`              |
