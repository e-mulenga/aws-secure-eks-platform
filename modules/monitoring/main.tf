# ============================================================
# Module: monitoring — EKS Observability
# ============================================================
# WAF Pillars: Operational Excellence, Reliability
#
# Provisions:
#   - CloudWatch Container Insights namespace + DaemonSet
#   - CloudWatch Log Groups (control plane + container logs)
#   - CloudWatch alarms: node CPU, memory, pod failures
#   - CloudWatch dashboard: cluster health overview
#   - CloudWatch alarm for GuardDuty EKS findings

locals { name_prefix = "${var.organization_name}-${var.environment}" }

# ---- CloudWatch Log Groups ---------------------------------
resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${local.name_prefix}-eks-container-insights" }
}

resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${local.name_prefix}-eks-app-logs" }
}

# ---- Container Insights Namespace --------------------------
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_container_insights ? 1 : 0
  metadata {
    name   = "amazon-cloudwatch"
    labels = { "app.kubernetes.io/managed-by" = "Terraform" }
  }
}

resource "kubernetes_service_account" "cloudwatch_agent" {
  count = var.enable_container_insights ? 1 : 0
  metadata {
    name      = "cloudwatch-agent"
    namespace = "amazon-cloudwatch"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.container_insights_role_arn
    }
  }
  depends_on = [kubernetes_namespace.amazon_cloudwatch]
}

# ---- CloudWatch Alarms -------------------------------------
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${local.name_prefix}-eks-node-cpu-high"
  alarm_description   = "EKS node CPU utilization > 80% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  dimensions          = { ClusterName = var.cluster_name }
  tags                = { Severity = "HIGH" }
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${local.name_prefix}-eks-node-memory-high"
  alarm_description   = "EKS node memory utilization > 85%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  dimensions          = { ClusterName = var.cluster_name }
  tags                = { Severity = "HIGH" }
}

resource "aws_cloudwatch_metric_alarm" "pod_restart_rate" {
  alarm_name          = "${local.name_prefix}-eks-pod-restart-rate"
  alarm_description   = "EKS pod restart rate is high — possible crash loop"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  dimensions          = { ClusterName = var.cluster_name }
  tags                = { Severity = "MEDIUM" }
}

resource "aws_cloudwatch_metric_alarm" "guardduty_eks_findings" {
  alarm_name          = "${local.name_prefix}-eks-guardduty-findings"
  alarm_description   = "GuardDuty detected threats in EKS cluster audit logs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HighSeverityFindingCount"
  namespace           = "AWS/GuardDuty"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  tags                = { Severity = "CRITICAL" }
}

# ---- CloudWatch Dashboard ----------------------------------
resource "aws_cloudwatch_dashboard" "eks" {
  dashboard_name = "${local.name_prefix}-eks-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          region   = var.aws_region
          markdown = "# ⚙️ EKS Platform — ${upper(var.environment)} | Cluster: **${var.cluster_name}** | Region: ${var.aws_region}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          region      = var.aws_region
          title       = "Node CPU Utilization (%)"
          period      = 300
          stat        = "Average"
          view        = "timeSeries"
          metrics     = [["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name]]
          annotations = { horizontal = [{ value = 80, label = "Alert threshold", color = "#ff6961" }] }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          region      = var.aws_region
          title       = "Node Memory Utilization (%)"
          period      = 300
          stat        = "Average"
          view        = "timeSeries"
          metrics     = [["ContainerInsights", "node_memory_utilization", "ClusterName", var.cluster_name]]
          annotations = { horizontal = [{ value = 85, label = "Alert threshold", color = "#ff6961" }] }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          region  = var.aws_region
          title   = "Pod Restarts (5 min)"
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
          metrics = [["ContainerInsights", "pod_number_of_container_restarts", "ClusterName", var.cluster_name]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          region  = var.aws_region
          title   = "Running Pods"
          period  = 60
          stat    = "Average"
          view    = "timeSeries"
          metrics = [["ContainerInsights", "pod_running", "ClusterName", var.cluster_name]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          region = var.aws_region
          title  = "Network I/O (bytes)"
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["ContainerInsights", "node_network_total_bytes", "ClusterName", var.cluster_name, { label = "Total" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 14
        width  = 24
        height = 4
        properties = {
          region = var.aws_region
          title  = "Active EKS Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.node_cpu_high.arn,
            aws_cloudwatch_metric_alarm.node_memory_high.arn,
            aws_cloudwatch_metric_alarm.pod_restart_rate.arn,
            aws_cloudwatch_metric_alarm.guardduty_eks_findings.arn
          ]
        }
      }
    ]
  })
}
