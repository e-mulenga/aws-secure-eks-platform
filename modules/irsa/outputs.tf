output "alb_controller_role_arn" {
  value = try(aws_iam_role.alb_controller[0].arn, null)
}

output "cluster_autoscaler_role_arn" {
  value = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}

output "external_secrets_role_arn" {
  value = try(aws_iam_role.external_secrets[0].arn, null)
}

output "ebs_csi_role_arn" {
  value = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "container_insights_role_arn" {
  value = try(aws_iam_role.container_insights[0].arn, null)
}