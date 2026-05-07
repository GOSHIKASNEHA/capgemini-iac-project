# -----------------------------------------------------------------------------
# Compute Module — Outputs
# -----------------------------------------------------------------------------
# Outputs expose key resource attributes so that other modules (load
# balancers, DNS, monitoring) can reference this compute layer without
# hard-coding resource identifiers.
# -----------------------------------------------------------------------------

# ─── Instance ────────────────────────────────────────────────────────────────

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "instance_public_ip" {
  description = "Public IPv4 address of the instance (empty if in a private subnet)."
  value       = aws_instance.this.public_ip
}

output "instance_private_ip" {
  description = "Private IPv4 address of the instance."
  value       = aws_instance.this.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the instance."
  value       = aws_instance.this.public_dns
}

output "instance_private_dns" {
  description = "Private DNS name of the instance."
  value       = aws_instance.this.private_dns
}

output "instance_state" {
  description = "Current state of the instance (running, stopped, etc.)."
  value       = aws_instance.this.instance_state
}

# ─── Security Group ──────────────────────────────────────────────────────────

output "security_group_id" {
  description = "ID of the instance security group."
  value       = aws_security_group.instance.id
}

output "security_group_arn" {
  description = "ARN of the instance security group."
  value       = aws_security_group.instance.arn
}

output "security_group_name" {
  description = "Name of the instance security group."
  value       = aws_security_group.instance.name
}

# ─── AMI ─────────────────────────────────────────────────────────────────────

output "ami_id" {
  description = "AMI ID used for the instance (resolved or user-supplied)."
  value       = local.ami_id
}
