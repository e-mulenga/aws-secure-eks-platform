# ============================================================
# Module: node-groups — EKS Managed Node Groups
# ============================================================
# WAF Pillars: Security, Reliability, Cost Optimization
#
# Every node group enforces:
#   - IMDSv2 (token-required) — prevents SSRF credential theft
#   - KMS-encrypted root EBS volumes
#   - No public IP on nodes (private subnet placement)
#   - SSM access instead of SSH (no inbound port 22)
#   - Auto-scaling with configurable min/max/desired
# ============================================================

locals {
  name_prefix = "${var.organization_name}-${var.environment}"
}

# ---- Node Security Group -----------------------------------
resource "aws_security_group" "nodes" {
  name        = "${local.name_prefix}-eks-nodes-sg"
  description = "EKS node group security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound for workload and control-plane communication"
  }

  tags = {
    Name                                        = "${local.name_prefix}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.nodes.id
  security_group_id        = aws_security_group.nodes.id
  description              = "Allow all inter-node communication"
}

# ---- Launch Template (hardening applied per node group) ----
resource "aws_launch_template" "nodes" {
  for_each = var.node_groups

  name_prefix = "${local.name_prefix}-${each.key}-"
  description = "Hardened launch template for EKS node group: ${each.key}"

  # Enforce IMDSv2 — prevents SSRF attacks stealing node credentials
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # KMS-encrypted root EBS volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size_gb
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  # No public IP assignment
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.nodes.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-${each.key}-node"
      NodeGroup   = each.key
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${local.name_prefix}-${each.key}-volume"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-${each.key}-lt" }
}

# ---- Managed Node Groups -----------------------------------
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = var.cluster_name
  node_group_name = "${local.name_prefix}-${each.key}"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type
  ami_type        = var.node_ami_type

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  launch_template {
    id      = aws_launch_template.nodes[each.key].id
    version = aws_launch_template.nodes[each.key].latest_version
  }

  labels = merge(
    { "node-group" = each.key, "environment" = var.environment },
    each.value.labels
  )

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value["key"]
      value  = try(taint.value["value"], null)
      effect = taint.value["effect"]
    }
  }

  tags = {
    Name                                            = "${local.name_prefix}-${each.key}"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
