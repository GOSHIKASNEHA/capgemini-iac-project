# =============================================================================
# Networking Module — Main Resources
# =============================================================================
# This module provisions a production-grade AWS VPC networking stack:
#
#   • VPC with configurable CIDR, DNS support, and DNS hostnames
#   • Public subnets  — one per AZ, with auto-assigned public IPs
#   • Private subnets — one per AZ, routed through NAT Gateway(s)
#   • Internet Gateway for public subnet egress
#   • NAT Gateway(s)  for private subnet egress (single or per-AZ)
#   • Dedicated route tables and associations for each subnet tier
#
# All resources are tagged consistently via `local.common_tags`.
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# 1. VPC
# ─────────────────────────────────────────────────────────────────────────────
# The Virtual Private Cloud is the foundational network boundary. All subnets,
# gateways, and route tables live inside it. DNS support and hostnames are
# enabled by default so that Route 53 private hosted zones and EC2 public DNS
# names work out of the box.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}


# ─────────────────────────────────────────────────────────────────────────────
# 2. Internet Gateway
# ─────────────────────────────────────────────────────────────────────────────
# The IGW provides a target for VPC route tables to route internet-bound
# traffic from public subnets. Without it, instances in public subnets would
# have no path to the internet even if they have a public IP.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}


# ─────────────────────────────────────────────────────────────────────────────
# 3. Public Subnets
# ─────────────────────────────────────────────────────────────────────────────
# Public subnets host resources that need direct internet access (ALBs, NAT
# Gateways, bastion hosts). Each is placed in a different AZ for fault
# tolerance. `map_public_ip_on_launch` ensures instances automatically get a
# public IPv4 address.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}


# ─────────────────────────────────────────────────────────────────────────────
# 4. Private Subnets
# ─────────────────────────────────────────────────────────────────────────────
# Private subnets host application servers, databases, and other workloads
# that should NOT be directly reachable from the internet.
#
# With NAT Gateway enabled:  private subnets can reach the internet outbound
# With NAT Gateway disabled: private subnets have VPC-only connectivity
#                            (sufficient for RDS, ElastiCache, internal ALBs)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}


# ─────────────────────────────────────────────────────────────────────────────
# 5. Elastic IPs for NAT Gateways
# ─────────────────────────────────────────────────────────────────────────────
# Each NAT Gateway requires a static Elastic IP. Using a dedicated EIP means
# the outbound IP is predictable, which is useful for firewall allowlisting on
# third-party APIs.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })

  # EIP must not be released before the IGW it depends on is destroyed,
  # otherwise Terraform may hit a dependency ordering error.
  depends_on = [aws_internet_gateway.this]
}


# ─────────────────────────────────────────────────────────────────────────────
# 6. NAT Gateways
# ─────────────────────────────────────────────────────────────────────────────
# NAT Gateways allow instances in private subnets to initiate outbound
# connections (e.g. OS updates, calls to AWS APIs) while remaining
# unreachable from the internet. They live in public subnets so they can
# route traffic via the Internet Gateway.
#
# Production deployments typically use one NAT Gateway per AZ to avoid
# cross-AZ traffic charges and to survive an AZ failure. Non-prod
# environments can use a single NAT Gateway to save cost.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}


# ─────────────────────────────────────────────────────────────────────────────
# 7. Public Route Table
# ─────────────────────────────────────────────────────────────────────────────
# A single route table is shared by all public subnets. Its default route
# (0.0.0.0/0) points to the Internet Gateway, giving public subnets direct
# internet access.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}


# ─────────────────────────────────────────────────────────────────────────────
# 8. Public Route Table Associations
# ─────────────────────────────────────────────────────────────────────────────
# Explicitly associating each public subnet with the public route table
# ensures they use the IGW route instead of the VPC's implicit main route
# table. This is a Terraform best practice — never rely on the main route
# table.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# ─────────────────────────────────────────────────────────────────────────────
# 9. Private Route Tables
# ─────────────────────────────────────────────────────────────────────────────
# When using one NAT Gateway per AZ, each AZ gets its own route table
# pointing to the local NAT Gateway. When using a single NAT Gateway, all
# private subnets share one route table. When NAT is disabled, a route table
# with no internet route is created (VPC-only connectivity).
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? local.nat_gateway_count : 1
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_route" "private_nat" {
  count = local.nat_gateway_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}


# ─────────────────────────────────────────────────────────────────────────────
# 10. Private Route Table Associations
# ─────────────────────────────────────────────────────────────────────────────
# Each private subnet is associated with the correct private route table.
# With per-AZ NAT Gateways the mapping is 1:1. With a single NAT Gateway
# all subnets point to index 0.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
