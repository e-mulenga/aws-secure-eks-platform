# ============================================================
# Module: eks-cluster — EKS Control Plane
# ============================================================
# WAF Pillars: Security, Reliability, Operational Excellence
#
# Provisions:
#   - EKS control plane with ALL log types enabled
#   - KMS envelope encryption for Kubernetes secrets
#   - Private API endpoint (no public exposure in prod)
#   - OIDC provider for IRSA
#   - Cluster IAM role + node IAM role
#   - Cluster security group with least-privilege rules
#   - EKS managed add-ons (CNI, CoreDNS, kube-proxy, CSI)
# ============================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.organization_name}-${var.environment}"
}

# ---- Cluster IAM Role --------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${local.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-eks-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

# ---- Node IAM Role -----------------------------------------
resource "aws_iam_role" "node" {
  name = "${local.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-eks-node-role" }
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ---- Cluster Security Group --------------------------------
resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS cluster control plane security group — managed by Terraform"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound for cluster operations"
  }

  tags = { Name = "${local.name_prefix}-eks-cluster-sg" }
}

# ---- CloudWatch Log Group for Control Plane ----------------
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${local.name_prefix}-eks-control-plane-logs" }
}

# ---- EKS Cluster -------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.control_plane_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : ["0.0.0.0/32"]
  }

  # KMS envelope encryption for all Kubernetes secrets
  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # Enable all control plane log types
  enabled_cluster_log_types = var.cluster_log_types

  kubernetes_network_config {
    service_ipv4_cidr = "172.20.0.0/16"
    ip_family         = "ipv4"
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = { Name = var.cluster_name }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policies,
    aws_cloudwatch_log_group.cluster
  ]
}

# ---- OIDC Provider for IRSA --------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = { Name = "${local.name_prefix}-eks-oidc-provider" }
}

# ---- Pipeline Role Access (kubectl from CI/CD) -------------
resource "aws_eks_access_entry" "pipeline" {
  count         = var.pipeline_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.pipeline_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "pipeline" {
  count         = var.pipeline_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.pipeline_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope { type = "cluster" }
}

# ---- EKS Managed Add-ons -----------------------------------
resource "aws_eks_addon" "addons" {
  for_each = var.addons

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.key
  addon_version               = each.value != "" ? each.value : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = { Name = "${local.name_prefix}-addon-${each.key}" }

  depends_on = [aws_eks_cluster.main]
}
