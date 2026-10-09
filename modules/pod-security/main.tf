# ============================================================
# Module: pod-security — Kubernetes Namespaces + Pod Security
# ============================================================
# WAF Pillars: Security, Operational Excellence
#
# Enforces Pod Security Standards (PSS) on all namespaces:
#   - "restricted" — most secure; no privileged containers,
#     enforces read-only root filesystem, drops all capabilities
#   - "baseline"  — prevents known privilege escalations
#   - "privileged" — no restrictions (system namespaces only)
#
# Creates application namespaces with labels that trigger the
# built-in Kubernetes Pod Security Admission controller.

resource "kubernetes_namespace" "application" {
  for_each = toset(var.application_namespaces)

  metadata {
    name = each.key
    labels = {
      "pod-security.kubernetes.io/enforce"         = var.pod_security_standards["enforce"]
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/audit"           = var.pod_security_standards["audit"]
      "pod-security.kubernetes.io/audit-version"   = "latest"
      "pod-security.kubernetes.io/warn"            = var.pod_security_standards["warn"]
      "pod-security.kubernetes.io/warn-version"    = "latest"
      "managed-by"                                 = "terraform"
      "environment"                                = var.environment
    }
    annotations = {
      "terraform-managed" = "true"
    }
  }
}

# ---- Default-deny NetworkPolicy per namespace ---------------
resource "kubernetes_network_policy" "default_deny" {
  for_each = toset(var.application_namespaces)

  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.application[each.key].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    # No ingress or egress rules = deny all traffic by default
  }
}

# ---- Allow DNS egress (required for all pods) ---------------
resource "kubernetes_network_policy" "allow_dns" {
  for_each = toset(var.application_namespaces)

  metadata {
    name      = "allow-dns-egress"
    namespace = kubernetes_namespace.application[each.key].metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

# ---- Resource Quota per namespace ---------------------------
resource "kubernetes_resource_quota" "namespace" {
  for_each = toset(var.application_namespaces)

  metadata {
    name      = "resource-quota"
    namespace = kubernetes_namespace.application[each.key].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.namespace_cpu_request_limit
      "requests.memory" = var.namespace_memory_request_limit
      "limits.cpu"      = var.namespace_cpu_limit
      "limits.memory"   = var.namespace_memory_limit
      "pods"            = var.namespace_pod_limit
    }
  }
}

# ---- LimitRange (enforce container resource requests) -------
resource "kubernetes_limit_range" "namespace" {
  for_each = toset(var.application_namespaces)

  metadata {
    name      = "limit-range"
    namespace = kubernetes_namespace.application[each.key].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      max = {
        cpu    = "2"
        memory = "2Gi"
      }
    }
  }
}
