# ============================================================
# AWS Secure EKS Platform — Variables
# ============================================================
# All configurable values are variables.
# No account IDs, regions, names, or secrets are hardcoded.
# ============================================================

# ---- Identity & Region -------------------------------------
variable "organization_name" {
  type        = string
  description = "Short organisation name used in all resource naming (3-30 lowercase chars)."
  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.organization_name))
    error_message = "Must be 3-30 lowercase alphanumeric characters or hyphens."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for the EKS cluster."
  default     = "af-south-1"
}

variable "dr_region" {
  type        = string
  description = "Secondary region for disaster recovery."
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev | test | prod."
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}

# ---- Governance & Tagging ----------------------------------
variable "owner" {
  type        = string
  description = "Team responsible for this EKS platform."
}

variable "cost_center" {
  type        = string
  description = "Cost center code for billing allocation."
}

# ---- Landing Zone Inputs -----------------------------------
variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN from Landing Zone for EKS secrets envelope encryption."
  sensitive   = true
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from terraform-enterprise-module-library vpc module output."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for EKS nodes (from vpc module output)."
}

variable "intra_subnet_ids" {
  type        = list(string)
  description = "Intra subnet IDs for EKS control plane ENIs (no internet route)."
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB (from vpc module output)."
  default     = []
}

# ---- DevSecOps Pipeline Inputs -----------------------------
variable "ecr_repository_urls" {
  type        = map(string)
  description = "ECR repository URLs from aws-devsecops-pipeline (map of name → URL)."
  default     = {}
}

variable "pipeline_role_arn" {
  type        = string
  description = "IAM role ARN used by the DevSecOps pipeline for EKS deployments."
  default     = ""
}

# ---- EKS Cluster Configuration ----------------------------
variable "cluster_name" {
  type        = string
  description = "EKS cluster name suffix (prefixed with org-env-)."
  default     = "platform"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster."
  default     = "1.29"
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Enable private API endpoint. Always true in production."
  default     = true
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Enable public API endpoint. Disable in production."
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint (if enabled)."
  default     = []
}

variable "cluster_log_types" {
  type        = list(string)
  description = "EKS control plane log types to enable."
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ---- Node Groups -------------------------------------------
variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size_gb   = number
    labels         = map(string)
    taints         = list(map(string))
  }))
  description = "Map of managed node group configurations."
  default = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      disk_size_gb   = 50
      labels         = { "role" = "general" }
      taints         = []
    }
  }
}

variable "node_ami_type" {
  type        = string
  description = "EKS node AMI type."
  default     = "AL2_x86_64"
  validation {
    condition     = contains(["AL2_x86_64", "AL2_ARM_64", "BOTTLEROCKET_x86_64", "BOTTLEROCKET_ARM_64"], var.node_ami_type)
    error_message = "Must be a valid EKS AMI type."
  }
}

# ---- Security & Networking ---------------------------------
variable "enable_pod_identity" {
  type        = bool
  description = "Enable EKS Pod Identity (newer alternative to IRSA)."
  default     = false
}

variable "cluster_security_group_additional_rules" {
  type        = map(any)
  description = "Additional security group rules for the cluster."
  default     = {}
}

variable "node_security_group_additional_rules" {
  type        = map(any)
  description = "Additional security group rules for node groups."
  default     = {}
}

# ---- EKS Add-ons -------------------------------------------
variable "cluster_addons" {
  type        = map(string)
  description = "Map of EKS addon name to version. Empty string = latest."
  default = {
    coredns             = ""
    kube-proxy          = ""
    vpc-cni             = ""
    aws-ebs-csi-driver  = ""
    aws-efs-csi-driver  = ""
    snapshot-controller = ""
  }
}

# ---- Helm Charts -------------------------------------------
variable "enable_aws_load_balancer_controller" {
  type        = bool
  description = "Deploy AWS Load Balancer Controller via Helm."
  default     = true
}

variable "enable_cluster_autoscaler" {
  type        = bool
  description = "Deploy Cluster Autoscaler via Helm."
  default     = true
}

variable "enable_metrics_server" {
  type        = bool
  description = "Deploy Metrics Server for HPA."
  default     = true
}

variable "enable_external_secrets" {
  type        = bool
  description = "Deploy External Secrets Operator for Secrets Manager integration."
  default     = true
}

variable "enable_falco" {
  type        = bool
  description = "Deploy Falco runtime security monitoring."
  default     = true
}

variable "enable_karpenter" {
  type        = bool
  description = "Deploy Karpenter for intelligent node provisioning."
  default     = false
}

# ---- Pod Security ------------------------------------------
variable "pod_security_standards" {
  type        = map(string)
  description = "Pod Security Standards per namespace (enforce/warn/audit level)."
  default = {
    enforce = "restricted"
    audit   = "restricted"
    warn    = "restricted"
  }
}

# ---- Monitoring & Observability ----------------------------
variable "enable_container_insights" {
  type        = bool
  description = "Enable CloudWatch Container Insights for the cluster."
  default     = true
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention period in days."
  default     = 90
}

# ---- Application Namespaces --------------------------------
variable "application_namespaces" {
  type        = list(string)
  description = "Application namespaces to create with Pod Security Standards enforced."
  default     = ["app", "data", "monitoring", "security"]
}

# ---- ACM Certificate (for ALB TLS) -------------------------
variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for ALB HTTPS listeners."
  default     = ""
}

# ---- Notifications -----------------------------------------
variable "alarm_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for CloudWatch alarm notifications (from SOC module)."
  default     = ""
}
