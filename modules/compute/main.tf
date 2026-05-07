# =============================================================================
# Compute Module — Main Resources
# =============================================================================
# This module provisions a production-grade AWS EC2 instance with:
#
#   • Automatic AMI lookup (latest Amazon Linux 2023) or explicit AMI
#   • Security group with granular ingress/egress rules
#   • SSH access restricted to configurable CIDR blocks
#   • gp3 root volume with configurable size
#   • IMDSv2 enforcement for metadata security
#   • Consistent tagging via `local.common_tags`
#
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# 1. AMI Data Source
# ─────────────────────────────────────────────────────────────────────────────
# Looks up the latest Amazon Linux 2023 AMI owned by Amazon. This keeps the
# module evergreen — you always get the newest patched image without manually
# updating the AMI ID. Used only when `var.ami_id` is not provided.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# 2. Security Group
# ─────────────────────────────────────────────────────────────────────────────
# Acts as a virtual firewall controlling inbound and outbound traffic for the
# EC2 instance. We define individual `aws_security_group_rule` resources
# (instead of inline blocks) so that rules can be added or removed without
# forcing a replacement of the entire security group.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-instance-sg"
  description = "Security group for ${local.name_prefix} EC2 instance"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-instance-sg"
  })

  # Ensure the replacement SG is created before the old one is destroyed,
  # preventing a window where the instance has no SG attached.
  lifecycle {
    create_before_destroy = true
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# 3. Security Group Rules
# ─────────────────────────────────────────────────────────────────────────────
# Defined as separate resources for modularity. Each rule documents its
# purpose and can be independently managed.
# ─────────────────────────────────────────────────────────────────────────────

# ── Ingress: SSH ─────────────────────────────────────────────────────────────
# Allows inbound SSH connections from specified CIDR blocks. In production,
# restrict `ssh_allowed_cidrs` to your corporate VPN or bastion host IP.

resource "aws_security_group_rule" "ssh_ingress" {
  type              = "ingress"
  description       = "Allow SSH access from permitted CIDRs"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.ssh_allowed_cidrs
  security_group_id = aws_security_group.instance.id
}

# ── Egress: All traffic ─────────────────────────────────────────────────────
# Allows all outbound traffic so the instance can reach package repos, AWS
# APIs, and external services. Restricting egress is possible but rarely done
# for general-purpose compute instances.

resource "aws_security_group_rule" "all_egress" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance.id
}


# ─────────────────────────────────────────────────────────────────────────────
# 4. EC2 Instance
# ─────────────────────────────────────────────────────────────────────────────
# The core compute resource. Key production hardening:
#
#   • IMDSv2 enforced — prevents SSRF-based credential theft (the #1 attack
#     vector on EC2). `http_tokens = "required"` blocks IMDSv1 entirely.
#   • gp3 root volume — 3,000 IOPS baseline (3× more than gp2) at lower cost.
#   • `monitoring = true` — enables detailed CloudWatch metrics (1-min).
#   • EBS optimization — enabled by default on most current-gen types.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = var.associate_public_ip
  monitoring                  = true
  user_data                   = var.user_data != "" ? var.user_data : null

  # ── Root Volume ──────────────────────────────────────────────────────────
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true            # Encrypt at rest — compliance must-have
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-root-vol"
    })
  }

  # ── Metadata Service (IMDSv2) ───────────────────────────────────────────
  # Enforcing IMDSv2 (token-required) prevents Server-Side Request Forgery
  # (SSRF) attacks from stealing instance credentials via the metadata
  # endpoint. This is an AWS security best practice.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-instance"
  })
}
