# Database Module

Production-hardened AWS RDS MySQL module for the Capgemini IaC project.

## Architecture

```
                    Internet
                       │
                       ✕  BLOCKED (no public access)
                       │
┌──────────────────────┼──────────────────────────────────────────┐
│                      │              VPC                         │
│  ┌───────────────────┼──────────────┐                          │
│  │         Public Subnets           │                          │
│  │  ┌────────────┐                  │                          │
│  │  │ EC2 (App)  │──────────┐       │                          │
│  │  │ SG: sg-app │          │       │                          │
│  │  └────────────┘          │       │                          │
│  └──────────────────────────┼───────┘                          │
│                             │ TCP 3306 (allowed via SG rule)   │
│  ┌──────────────────────────┼───────┐                          │
│  │        Private Subnets   │       │                          │
│  │  ┌──────────────────────▼────┐   │                          │
│  │  │       RDS MySQL           │   │                          │
│  │  │  SG: sg-db (ingress from  │   │                          │
│  │  │       sg-app only)        │   │                          │
│  │  │  Encrypted at rest (KMS)  │   │                          │
│  │  │  Multi-AZ (optional)      │   │                          │
│  │  └───────────────────────────┘   │                          │
│  └──────────────────────────────────┘                          │
└────────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "database" {
  source = "./modules/database"

  project_name = "capgemini"
  environment  = "prod"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  allowed_security_group_ids = [module.compute.security_group_id]

  db_name     = "appdb"
  db_username = "dbadmin"
  db_password = var.db_password  # from tfvars or secrets manager

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  multi_az          = true
  deletion_protection = true
}
```

## Resources Created

| Resource | Count | Purpose |
|----------|-------|---------|
| `aws_db_subnet_group` | 1 | Places RDS in private subnets |
| `aws_security_group` | 1 | Firewall for the database |
| `aws_security_group_rule` | 2-3 | Ingress from app SGs + egress |
| `aws_db_parameter_group` | 1 | Engine tuning (utf8mb4, slow queries) |
| `aws_iam_role` | 0/1 | Enhanced Monitoring permissions |
| `aws_db_instance` | 1 | The RDS MySQL instance |
