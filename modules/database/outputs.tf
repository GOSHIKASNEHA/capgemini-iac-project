# -----------------------------------------------------------------------------
# Database Module — Outputs
# -----------------------------------------------------------------------------

output "db_instance_id" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the RDS instance (without port)."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the database is listening on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master username."
  value       = aws_db_instance.this.username
}

output "db_security_group_id" {
  description = "ID of the database security group."
  value       = aws_security_group.db.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}

output "db_multi_az" {
  description = "Whether Multi-AZ is enabled."
  value       = aws_db_instance.this.multi_az
}

output "db_storage_encrypted" {
  description = "Whether storage encryption is enabled."
  value       = aws_db_instance.this.storage_encrypted
}

output "db_engine_version_actual" {
  description = "Actual engine version running."
  value       = aws_db_instance.this.engine_version_actual
}
