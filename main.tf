# ============================================================
# AWS Secure EKS Platform — Root Orchestration
# ============================================================
# Deployment order:
#   1. EKS Cluster (control plane, OIDC provider)
#   2. Node Groups  (compute, after cluster ready)
#   3. IRSA Roles   (IAM roles for service accounts)
#   4. EKS Add-ons  (CNI, CSI, CoreDNS, kube-proxy)
#   5. Helm Add-ons (ALB controller, autoscaler, Falco…)
#   6. Pod Security (namespaces, admission policies)
#   7. Monitoring   (Container Insights, dashboards, alarms)
# ============================================================

# ---- 1. EKS Cluster -----------------------------------------
module "eks_cluster" {
  source = "./modules/eks-cluster"

  organization_name                    = var.organization_name
  environment                          = var.environment
  cluster_name                         = local.cluster_name
  kubernetes_version                   = var.kubernetes_version
  vpc_id                               = var.vpc_id
  subnet_ids                           = var.private_subnet_ids
  control_plane_subnet_ids             = length(var.intra_subnet_ids) > 0 ? var.intra_subnet_ids : var.private_subnet_ids
  kms_key_arn                          = var.kms_key_arn
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_log_types                    = var.cluster_log_types
  log_retention_days                   = var.log_retention_days
  account_id                           = local.account_id
  partition                            = local.partition
  pipeline_role_arn                    = var.pipeline_role_arn
  addons                               = var.cluster_addons
}

# ---- 2. Node Groups -----------------------------------------
module "node_groups" {
  source = "./modules/node-groups"

  organization_name = var.organization_name
  environment       = var.environment
  vpc_id            = var.vpc_id
  cluster_name      = module.eks_cluster.cluster_name
  node_role_arn     = module.eks_cluster.node_role_arn
  subnet_ids        = var.private_subnet_ids
  kms_key_arn       = var.kms_key_arn
  node_groups       = var.node_groups
  node_ami_type     = var.node_ami_type

  depends_on = [module.eks_cluster]
}

# ---- 3. IRSA Roles ------------------------------------------
module "irsa" {
  source = "./modules/irsa"

  organization_name         = var.organization_name
  environment               = var.environment
  cluster_name              = module.eks_cluster.cluster_name
  oidc_provider_arn         = module.eks_cluster.oidc_provider_arn
  oidc_provider_url         = module.eks_cluster.oidc_provider_url
  account_id                = local.account_id
  partition                 = local.partition
  region                    = local.region
  vpc_id                    = var.vpc_id
  enable_alb_controller     = var.enable_aws_load_balancer_controller
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  enable_external_secrets   = var.enable_external_secrets
  enable_ebs_csi            = true
  enable_container_insights = var.enable_container_insights
  kms_key_arn               = var.kms_key_arn

  depends_on = [module.eks_cluster]
}

# ---- 4. Helm Add-ons ----------------------------------------
module "eks_addons" {
  source = "./modules/eks-addons"

  organization_name                   = var.organization_name
  environment                         = var.environment
  cluster_name                        = module.eks_cluster.cluster_name
  region                              = local.region
  account_id                          = local.account_id
  vpc_id                              = var.vpc_id
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  alb_controller_role_arn             = module.irsa.alb_controller_role_arn
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  cluster_autoscaler_role_arn         = module.irsa.cluster_autoscaler_role_arn
  enable_metrics_server               = var.enable_metrics_server
  enable_external_secrets             = var.enable_external_secrets
  external_secrets_role_arn           = module.irsa.external_secrets_role_arn
  enable_falco                        = var.enable_falco
  alarm_sns_topic_arn                 = var.alarm_sns_topic_arn

  depends_on = [module.node_groups, module.irsa]
}

# ---- 5. Pod Security ----------------------------------------
module "pod_security" {
  source = "./modules/pod-security"

  organization_name      = var.organization_name
  environment            = var.environment
  application_namespaces = var.application_namespaces
  pod_security_standards = var.pod_security_standards

  depends_on = [module.eks_addons]
}

# ---- 6. Monitoring ------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  organization_name           = var.organization_name
  environment                 = var.environment
  cluster_name                = module.eks_cluster.cluster_name
  region                      = local.region
  account_id                  = local.account_id
  enable_container_insights   = var.enable_container_insights
  container_insights_role_arn = module.irsa.container_insights_role_arn
  log_retention_days          = var.log_retention_days
  kms_key_arn                 = var.kms_key_arn
  alarm_sns_topic_arn         = var.alarm_sns_topic_arn

  depends_on = [module.eks_addons]
}
