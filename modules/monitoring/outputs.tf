output "log_group_name" { value = aws_cloudwatch_log_group.container_insights.name }
output "dashboard_name" { value = aws_cloudwatch_dashboard.eks.dashboard_name }
output "dashboard_arn" { value = aws_cloudwatch_dashboard.eks.dashboard_arn }
output "cpu_alarm_arn" { value = aws_cloudwatch_metric_alarm.node_cpu_high.arn }
output "memory_alarm_arn" { value = aws_cloudwatch_metric_alarm.node_memory_high.arn }
