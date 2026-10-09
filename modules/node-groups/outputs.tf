output "node_group_names" {
  value = { for k, v in aws_eks_node_group.main : k => v.node_group_name }
}

output "node_group_arns" {
  value = { for k, v in aws_eks_node_group.main : k => v.arn }
}

output "node_security_group_id" {
  value = aws_security_group.nodes.id
}

output "launch_template_ids" {
  value = { for k, v in aws_launch_template.nodes : k => v.id }
}
