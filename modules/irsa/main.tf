# ============================================================
# Module: irsa — IAM Roles for Service Accounts
# ============================================================
# WAF Pillars: Security, Operational Excellence
#
# Creates IRSA roles for all core platform add-ons:
#   - AWS Load Balancer Controller
#   - Cluster Autoscaler
#   - External Secrets Operator
#   - EBS CSI Driver
#   - CloudWatch Container Insights (agent)
#
# Each role uses a narrowly-scoped OIDC condition binding the
# role to a specific Kubernetes service account in a specific
# namespace — preventing pod impersonation across namespaces.
# ============================================================

locals {
  name_prefix  = "${var.organization_name}-${var.environment}"
  oidc_sub_url = replace(var.oidc_provider_url, "https://", "")
}

# ---- AWS Load Balancer Controller IRSA ---------------------
resource "aws_iam_role" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0
  name  = "${local.name_prefix}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-alb-controller-role" }
}

resource "aws_iam_role_policy" "alb_controller" {
  count = var.enable_alb_controller ? 1 : 0
  name  = "alb-controller-policy"
  role  = aws_iam_role.alb_controller[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs", "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances", "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags", "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools", "elasticloadbalancing:*",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates", "acm:DescribeCertificate",
          "wafv2:GetWebACL", "wafv2:GetWebACLForResource",
          "wafv2:ListWebACLs", "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState", "shield:DescribeProtection",
          "shield:CreateProtection", "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroupRules",
        "ec2:ModifySecurityGroupRules", "ec2:RevokeSecurityGroupEgress"]
        Resource = "*"
      }
    ]
  })
}

# ---- Cluster Autoscaler IRSA --------------------------------
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "${local.name_prefix}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-cluster-autoscaler-role" }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "cluster-autoscaler-policy"
  role  = aws_iam_role.cluster_autoscaler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages", "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })
}

# ---- External Secrets Operator IRSA -------------------------
resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0
  name  = "${local.name_prefix}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-external-secrets-role" }
}

resource "aws_iam_role_policy" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0
  name  = "external-secrets-policy"
  role  = aws_iam_role.external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"]
        Resource = "arn:${var.partition}:secretsmanager:${aws_region}:${var.account_id}:secret:${var.organization_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:${var.partition}:ssm:${aws_region}:${var.account_id}:parameter/${var.organization_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

# ---- EBS CSI Driver IRSA ------------------------------------
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi ? 1 : 0
  name  = "${local.name_prefix}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = { Name = "${local.name_prefix}-ebs-csi-role" }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_ebs_csi ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy" "ebs_csi_kms" {
  count = var.enable_ebs_csi ? 1 : 0
  name  = "ebs-csi-kms-decrypt"
  role  = aws_iam_role.ebs_csi[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant",
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey"]
      Resource = [var.kms_key_arn]
    }]
  })
}

# ---- CloudWatch Container Insights IRSA --------------------
resource "aws_iam_role" "container_insights" {
  count = var.enable_container_insights ? 1 : 0
  name  = "${local.name_prefix}-container-insights-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub_url}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "container_insights" {
  count      = var.enable_container_insights ? 1 : 0
  role       = aws_iam_role.container_insights[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
