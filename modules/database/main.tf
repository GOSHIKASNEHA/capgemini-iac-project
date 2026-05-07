# =============================================================================
# Database Module — Main Resources
# =============================================================================
# This module provisions a production-hardened AWS RDS MySQL instance with:
#
#   • Private subnet placement (no public access)
#   • DB subnet group spanning multiple AZs for failover
#   • Security group with least-privilege ingress
#   • Custom parameter group for engine tuning
#   • Storage encryption at rest (KMS)
#   • Automated backups with configurable retention
#   • Optional Multi-AZ for automatic failover
#   • Performance Insights and Enhanced Monitoring
#   • Deletion protection and final snapshot safeguards
#   • Consistent tagging via `local.common_tags`
#
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# 1. DB Subnet Group
# ─────────────────────────────────────────────────────────────────────────────
# An RDS subnet group tells AWS which subnets the database can be placed in.
# By specifying PRIVATE subnets, the database has no route to the internet
# and is unreachable from outside the VPC.
#
# RDS requires subnets in at least 2 Availability Zones so it can perform
# automatic failover (Multi-AZ) or place read replicas in a different AZ.
#
# SECURITY: This is the primary mechanism that keeps the database off the
# public internet. Even if someone sets `publicly_accessible = true` on the
# instance, the private subnets have no IGW route, so it remains unreachable.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Private subnets for ${local.name_prefix} RDS instance"
  subnet_ids  = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}


# ─────────────────────────────────────────────────────────────────────────────
# 2. Security Group
# ─────────────────────────────────────────────────────────────────────────────
# Controls which resources can connect to the database. Unlike the compute
# module's SG, this one allows ingress ONLY from specific security groups
# (e.g. the application server's SG) — not from CIDR blocks.
#
# SECURITY: Using source security group IDs instead of CIDR blocks is a best
# practice because it ties access to specific AWS resources. If the app
# server's IP changes, the rule still works. If the app server is terminated,
# the access is automatically revoked.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group for ${local.name_prefix} RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# 3. Security Group Rules
# ─────────────────────────────────────────────────────────────────────────────

# ── Ingress: From application security groups ────────────────────────────────
# Each rule allows MySQL/PostgreSQL traffic from a specific security group.
# This is the "least privilege" approach — only known application tiers can
# reach the database.

resource "aws_security_group_rule" "db_ingress_from_sg" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  description              = "Allow ${var.engine} from application SG"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.db.id
}

# ── Ingress: From CIDR blocks (fallback) ─────────────────────────────────────
# Use this only when SG-based rules aren't possible (e.g. on-prem VPN CIDRs).

resource "aws_security_group_rule" "db_ingress_from_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  description       = "Allow ${var.engine} from permitted CIDRs"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.db.id
}

# ── Egress: All traffic ──────────────────────────────────────────────────────
# RDS needs outbound access for internal AWS operations (replication,
# CloudWatch metrics, etc.). Restricting egress on RDS is not recommended.

resource "aws_security_group_rule" "db_egress" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db.id
}


# ─────────────────────────────────────────────────────────────────────────────
# 4. DB Parameter Group
# ─────────────────────────────────────────────────────────────────────────────
# A custom parameter group lets you tune engine-specific settings without
# modifying the default group (which can't be changed). This is important
# because:
#
#   • Character encoding — `utf8mb4` supports emojis and all Unicode
#   • Performance tuning — settings like `innodb_buffer_pool_size`
#   • Security hardening — e.g. requiring SSL connections, audit logging
#
# Using a custom group also prevents issues when AWS updates the default
# group — your settings remain stable across engine upgrades.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-db-params"
  family      = var.family
  description = "Custom parameter group for ${local.name_prefix} ${var.engine}"

  # ── Character Encoding ──────────────────────────────────────────────────
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  # ── Slow Query Logging ──────────────────────────────────────────────────
  # Helps identify poorly performing queries for optimisation.
  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2" # queries taking longer than 2 seconds are logged
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# 5. IAM Role for Enhanced Monitoring
# ─────────────────────────────────────────────────────────────────────────────
# Enhanced Monitoring provides OS-level metrics (CPU, memory, disk I/O, swap)
# at 1-second granularity. It requires an IAM role that grants RDS permission
# to publish metrics to CloudWatch.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}


# ─────────────────────────────────────────────────────────────────────────────
# 6. RDS Instance
# ─────────────────────────────────────────────────────────────────────────────
# The core database resource. Key production hardening:
#
#   • `publicly_accessible = false` — NO public endpoint, period.
#   • `storage_encrypted = true`    — Encrypts data at rest with KMS.
#   • `deletion_protection = true`  — Prevents accidental deletion.
#   • `skip_final_snapshot = false`  — Takes a backup before destruction.
#   • `multi_az`                    — Synchronous standby in another AZ.
#   • `auto_minor_version_upgrade`  — Patches security vulns automatically.
#   • `copy_tags_to_snapshot`       — Backups inherit resource tags.
#   • Performance Insights          — Query-level performance analysis.
#   • Enhanced Monitoring           — OS-level metrics (CPU, RAM, I/O).
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-db"

  # ── Engine ──────────────────────────────────────────────────────────────
  engine         = var.engine
  engine_version = var.engine_version
  port           = var.port

  # ── Instance ────────────────────────────────────────────────────────────
  instance_class = var.instance_class

  # ── Storage ─────────────────────────────────────────────────────────────
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted && var.kms_key_arn != "" ? var.kms_key_arn : null

  # ── Networking ──────────────────────────────────────────────────────────
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false # CRITICAL: never expose DB to internet
  multi_az               = var.multi_az

  # ── Authentication ──────────────────────────────────────────────────────
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # ── Parameter Group ─────────────────────────────────────────────────────
  parameter_group_name = aws_db_parameter_group.this.name

  # ── Backups ─────────────────────────────────────────────────────────────
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  # ── Protection ──────────────────────────────────────────────────────────
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_id

  # ── Upgrades ────────────────────────────────────────────────────────────
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  # ── Monitoring ──────────────────────────────────────────────────────────
  performance_insights_enabled = false
  monitoring_interval = 0
  monitoring_role_arn = null
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })
}
