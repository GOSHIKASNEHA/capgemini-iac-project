# -----------------------------------------------------------------------------
# Networking Module — Outputs
# -----------------------------------------------------------------------------
# Outputs expose key resource IDs and attributes so that other modules
# (compute, database, storage) can reference this networking layer without
# hard-coding resource identifiers.
# -----------------------------------------------------------------------------

# ─── VPC ─────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.this.arn
}

# ─── Subnets ─────────────────────────────────────────────────────────────────

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of the public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of the private subnets."
  value       = aws_subnet.private[*].cidr_block
}

# ─── Internet Gateway ───────────────────────────────────────────────────────

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

# ─── NAT Gateways ───────────────────────────────────────────────────────────

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateway(s). Empty when NAT is disabled."
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public (Elastic) IPs assigned to the NAT Gateway(s)."
  value       = aws_eip.nat[*].public_ip
}

# ─── Route Tables ────────────────────────────────────────────────────────────

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of the private route table(s)."
  value       = aws_route_table.private[*].id
}

# ─── Availability Zones ─────────────────────────────────────────────────────

output "availability_zones" {
  description = "List of Availability Zones used by this networking stack."
  value       = var.availability_zones
}
