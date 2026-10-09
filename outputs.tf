# ============================================================
# AWS Secure EKS Platform — Outputs
# ============================================================
# Outputs consumed by multi-cloud-governance (Position 6)
# and used by application teams to configure kubectl access.
# ============================================================

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks_cluster.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = module.eks_cluster.cluster_endpoint
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster."
  value       = module.eks_cluster.cluster_version
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks_cluster.cluster_ca_certificate
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used to create IRSA roles for workloads."
  value       = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL."
  value       = module.eks_cluster.oidc_provider_url
}

output "node_role_arn" {
  description = "IAM role ARN used by EKS managed node groups."
  value       = module.eks_cluster.node_role_arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks_cluster.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID used by EKS node groups."
  value       = module.node_groups.node_security_group_id
}

# ---- IRSA Role ARNs (for workload teams) -------------------
output "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller."
  value       = module.irsa.alb_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for the Cluster Autoscaler."
  value       = module.irsa.cluster_autoscaler_role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for the External Secrets Operator."
  value       = module.irsa.external_secrets_role_arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver."
  value       = module.irsa.ebs_csi_role_arn
}

# ---- Monitoring outputs ------------------------------------
output "container_insights_log_group" {
  description = "CloudWatch Log Group for Container Insights."
  value       = module.monitoring.log_group_name
}

output "eks_dashboard_name" {
  description = "CloudWatch EKS operations dashboard name."
  value       = module.monitoring.dashboard_name
}

# ---- kubectl config command --------------------------------
output "kubeconfig_command" {
  description = "AWS CLI command to update local kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks_cluster.cluster_name} --region ${var.aws_region}"
}
