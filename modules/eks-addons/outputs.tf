output "alb_controller_deployed" { value = var.enable_aws_load_balancer_controller }
output "cluster_autoscaler_deployed" { value = var.enable_cluster_autoscaler }
output "falco_deployed" { value = var.enable_falco }
output "external_secrets_deployed" { value = var.enable_external_secrets }
