# =============================================================================
# Root Configuration — Module Composition
# =============================================================================
#
# This file wires together four infrastructure modules into a complete
# production environment. The modules are ordered by their dependency chain:
#
#   networking  ──►  compute  ──►  database
#                                   ▲
#                    networking ─────┘
#
#   storage (independent — no cross-module dependencies)
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │                        MODULE DEPENDENCY GRAPH                         │
# │                                                                        │
# │  ┌──────────────┐                                                      │
# │  │  networking   │─── vpc_id ──────────────────────►┌────────────┐     │
# │  │              │─── public_subnet_ids[0] ─────────►│  compute   │     │
# │  │              │                                   └─────┬──────┘     │
# │  │              │─── vpc_id ──────────────────────►┌──────▼──────┐     │
# │  │              │─── private_subnet_ids ──────────►│  database   │     │
# │  └──────────────┘                                  │             │     │
# │                    security_group_id ─────────────►│ (SG ingress)│     │
# │                    (from compute)                  └─────────────┘     │
# │                                                                        │
# │  ┌──────────────┐                                                      │
# │  │   storage    │  (standalone — no cross-module dependencies)         │
# │  └──────────────┘                                                      │
# └─────────────────────────────────────────────────────────────────────────┘
#
# =============================================================================


# =============================================================================
# 1. NETWORKING MODULE (Foundation Layer)
# =============================================================================
# This is the foundational module — all other modules depend on it.
# It creates the VPC, subnets, gateways, and route tables that form the
# network fabric everything else runs on.
#
# Outputs consumed by other modules:
#   ├── vpc_id              → compute (SG creation), database (SG creation)
#   ├── public_subnet_ids   → compute (EC2 placement)
#   └── private_subnet_ids  → database (RDS placement, DB subnet group)
#
# No dependencies on other modules.
# =============================================================================

module "networking" {
  source = "./modules/networking"

  # ── Identity (shared across all modules for consistent naming/tagging) ──
  project_name = var.project_name
  environment  = var.environment

  # ── VPC Configuration ──────────────────────────────────────────────────
  vpc_cidr = var.vpc_cidr

  # ── Subnet Layout ──────────────────────────────────────────────────────
  # Public subnets  → for internet-facing resources (ALB, EC2, NAT GW)
  # Private subnets → for internal resources (RDS, app servers, caches)
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # ── NAT Gateway ────────────────────────────────────────────────────────
  # Required for private subnets to reach the internet (package updates,
  # AWS API calls). Single NAT GW saves cost in dev; per-AZ in prod.
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}


# =============================================================================
# 2. COMPUTE MODULE (Application Layer)
# =============================================================================
# Creates the EC2 instance that runs the application code. Depends on the
# networking module for VPC and subnet placement.
#
# Module connections:
#   ├── FROM networking.vpc_id             → creates SG in the same VPC
#   ├── FROM networking.public_subnet_ids  → launches EC2 in public subnet
#   └── TO   database (via security_group_id output)
#            → database SG allows ingress ONLY from this instance's SG
#
# Why public subnet?
#   The EC2 instance needs a public IP for SSH access and to serve traffic
#   directly. In production, you'd put it behind an ALB and move it to a
#   private subnet.
# =============================================================================

module "compute" {
  source = "./modules/compute"

  # ── Identity ────────────────────────────────────────────────────────────
  project_name = var.project_name
  environment  = var.environment

  # ── Networking (consumed from networking module outputs) ────────────────
  # vpc_id:    Security group must be created in the same VPC as the instance
  # subnet_id: Places the instance in the first public subnet (AZ-a)
  vpc_id    = module.networking.vpc_id               # ◄── networking output
  subnet_id = module.networking.public_subnet_ids[0] # ◄── networking output

  # ── Instance Configuration ─────────────────────────────────────────────
  instance_type       = var.instance_type
  key_name            = var.key_name
  associate_public_ip = true
  root_volume_size    = var.root_volume_size
  ssh_allowed_cidrs   = var.ssh_allowed_cidrs
}


# =============================================================================
# 3. STORAGE MODULE (Data Layer — Object Storage)
# =============================================================================
# Creates an S3 bucket for application data, backups, or static assets.
# This module is STANDALONE — it has no cross-module dependencies.
#
# Module connections:
#   ├── None inbound (does not consume other module outputs)
#   └── None outbound (no other module depends on storage outputs)
#
# The storage module is intentionally decoupled so it can be deployed or
# destroyed independently without affecting compute or database.
#
# Environment-aware settings:
#   • force_destroy: true in dev/staging (easy teardown), false in prod
# =============================================================================

module "storage" {
  source = "./modules/storage"

  # ── Identity ────────────────────────────────────────────────────────────
  project_name = var.project_name
  environment  = var.environment

  # ── Bucket Configuration ───────────────────────────────────────────────
  force_destroy     = var.environment != "prod" # safe delete in non-prod only
  enable_versioning = true
  sse_algorithm     = "aws:kms"

  # ── Lifecycle Rules (cost management) ──────────────────────────────────
  enable_lifecycle_rules             = true
  noncurrent_version_transition_days = 30 # old versions → Glacier after 30d
  noncurrent_version_expiration_days = 90 # old versions deleted after 90d
}


# =============================================================================
# 4. DATABASE MODULE (Data Layer — Relational)
# =============================================================================
# Creates an RDS MySQL instance in PRIVATE subnets. This module has the most
# cross-module dependencies — it consumes outputs from both networking AND
# compute modules.
#
# Module connections:
#   ├── FROM networking.vpc_id             → creates DB security group in VPC
#   ├── FROM networking.private_subnet_ids → DB subnet group (private only!)
#   └── FROM compute.security_group_id     → SG ingress rule allows ONLY the
#                                            app server to connect on port 3306
#
# Why private subnets?
#   Databases must NEVER be on the public internet. Private subnets have no
#   IGW route, making the RDS instance unreachable from outside the VPC.
#
# Why compute SG as ingress source?
#   Using source_security_group_id (instead of CIDR blocks) ties database
#   access to the application instance itself. If the instance is terminated,
#   the access is automatically revoked. If its IP changes, the rule still
#   works.
#
# Environment-aware settings:
#   • multi_az:            true in prod (automatic failover)
#   • deletion_protection: true in prod (prevents accidental deletion)
#   • skip_final_snapshot: false in prod (forces backup before destroy)
# =============================================================================

module "database" {
  source = "./modules/database"

  # ── Identity ────────────────────────────────────────────────────────────
  project_name = var.project_name
  environment  = var.environment

  # ── Networking (consumed from networking module outputs) ────────────────
  # vpc_id:             DB security group must live in the same VPC
  # private_subnet_ids: DB subnet group places RDS in private subnets
  #                     (no internet gateway route = no public access)
  vpc_id             = module.networking.vpc_id             # ◄── networking output
  private_subnet_ids = module.networking.private_subnet_ids # ◄── networking output

  # ── Access Control (consumed from compute module output) ───────────────
  # Only the compute instance's security group can connect to the DB.
  # This creates an SG ingress rule: "allow TCP 3306 from sg-compute"
  allowed_security_group_ids = [module.compute.security_group_id] # ◄── compute output

  # ── Engine ──────────────────────────────────────────────────────────────
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class
  port           = 3306

  # ── Storage ─────────────────────────────────────────────────────────────
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100  # autoscaling ceiling
  storage_encrypted     = true # KMS encryption at rest

  # ── Authentication ──────────────────────────────────────────────────────
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password # sensitive — never logged or output

  # ── High Availability & Backups ─────────────────────────────────────────
  multi_az                = var.environment == "prod" # standby in another AZ
  backup_retention_period = 0                         # 7 days of PITR

  # ── Destruction Safeguards ─────────────────────────────────────────────
  deletion_protection = var.environment == "prod" # can't delete without disabling
  skip_final_snapshot = var.environment != "prod" # force backup in prod
}
