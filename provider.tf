# ============================================================
# AWS Secure EKS Platform — Provider Configuration
# ============================================================
# Portfolio Standard: provider.tf contains BOTH the terraform{}
# block AND all provider configurations. No versions.tf.
#
# Portfolio Position: 5 of 6
# Depends on:
#   - aws-enterprise-landing-zone   (VPC, KMS, IAM Identity Center,
#                                    account structure, GuardDuty)
#   - terraform-enterprise-module-library (vpc, iam, kms, alb modules)
#   - aws-devsecops-pipeline         (ECR image registry, OIDC, pipeline)
# Consumed by:
#   - multi-cloud-governance         (cluster posture, findings)
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote backend — overridden per environment in environments/<env>/backend.tf
  backend "s3" {}
}

# ---- AWS Provider (EKS workload account) -------------------
provider "aws" {
  region = aws_region

  default_tags {
    tags = {
      Project     = "aws-secure-eks-platform"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Repository  = "aws-secure-eks-platform"
      Portfolio   = "enterprise-cloud-platform"
    }
  }
}

# ---- Kubernetes provider (configured after cluster creation) -
# Uses the EKS cluster endpoint and CA certificate from the
# aws_eks_cluster data source once the cluster exists.
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks_cluster.cluster_name,
      "--region", aws_region
    ]
  }
}

# ---- Helm provider (same authentication as kubernetes) ------
provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks_cluster.cluster_name,
        "--region", var.aws_region
      ]
    }
  }
}
