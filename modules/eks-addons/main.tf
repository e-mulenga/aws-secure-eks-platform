# ============================================================
# Module: eks-addons — Helm Chart Deployments
# ============================================================
# Deploys core platform add-ons via Helm:
#   - AWS Load Balancer Controller
#   - Cluster Autoscaler
#   - Metrics Server (required for HPA)
#   - External Secrets Operator
#   - Falco (runtime security)

locals { name_prefix = "${var.organization_name}-${var.environment}" }

resource "helm_release" "aws_load_balancer_controller" {
  count      = var.enable_aws_load_balancer_controller ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"
  namespace  = "kube-system"
  atomic     = true
  timeout    = 300

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  # Security hardening
  set {
    name  = "podSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "podSecurityContext.runAsUser"
    value = "65534"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }
}

resource "helm_release" "cluster_autoscaler" {
  count      = var.enable_cluster_autoscaler ? 1 : 0
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.35.0"
  namespace  = "kube-system"
  atomic     = true
  timeout    = 300

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cluster_autoscaler_role_arn
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"
  }
}

resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"
  namespace  = "kube-system"
  atomic     = true

  set {
    name  = "args[0]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"
  }
}

resource "kubernetes_namespace" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0
  metadata {
    name = "external-secrets"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
    }
  }
}

resource "helm_release" "external_secrets" {
  count      = var.enable_external_secrets ? 1 : 0
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.9.14"
  namespace  = "external-secrets"
  atomic     = true
  timeout    = 300

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }
  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

resource "kubernetes_namespace" "falco" {
  count = var.enable_falco ? 1 : 0
  metadata {
    name   = "falco"
    labels = { "app.kubernetes.io/managed-by" = "Terraform" }
  }
}

resource "helm_release" "falco" {
  count      = var.enable_falco ? 1 : 0
  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  version    = "4.2.3"
  namespace  = "falco"
  atomic     = true
  timeout    = 300

  set {
    name  = "driver.kind"
    value = "ebpf"
  }

  set {
    name  = "falco.grpc.enabled"
    value = "true"
  }

  set {
    name  = "falco.grpcOutput.enabled"
    value = "true"
  }

  set {
    name  = "falco.json_output"
    value = "true"
  }

  set {
    name  = "falco.log_stderr"
    value = "true"
  }

  set {
    name  = "falcosidekick.enabled"
    value = "true"
  }

  set {
    name  = "falcosidekick.config.aws.sns.topicarn"
    value = var.alarm_sns_topic_arn
  }

  set {
    name  = "falcosidekick.config.aws.region"
    value = var.var.var.aws_region
  }

  set {
    name  = "falcosidekick.webui.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.falco]
}
