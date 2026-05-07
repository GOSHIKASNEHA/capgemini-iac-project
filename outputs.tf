# =============================================================================
# Root Configuration — Outputs
# =============================================================================
# Re-export networking outputs at the root level for easy consumption.
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = module.networking.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs."
  value       = module.networking.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "Elastic IPs of the NAT Gateways."
  value       = module.networking.nat_gateway_public_ips
}

# ─── Compute ─────────────────────────────────────────────────────────────────

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = module.compute.instance_public_ip
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance."
  value       = module.compute.instance_private_ip
}

output "security_group_id" {
  description = "ID of the instance security group."
  value       = module.compute.security_group_id
}

# ─── Storage ─────────────────────────────────────────────────────────────────

output "s3_bucket_id" {
  description = "Name of the S3 bucket."
  value       = module.storage.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = module.storage.bucket_arn
}

output "s3_versioning_status" {
  description = "Versioning status of the S3 bucket."
  value       = module.storage.versioning_status
}

# ─── Database ────────────────────────────────────────────────────────────────

output "db_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance."
  value       = module.database.db_endpoint
}

output "db_address" {
  description = "Hostname of the RDS instance."
  value       = module.database.db_address
}

output "db_port" {
  description = "Port the database is listening on."
  value       = module.database.db_port
}

output "db_security_group_id" {
  description = "ID of the database security group."
  value       = module.database.db_security_group_id
}
