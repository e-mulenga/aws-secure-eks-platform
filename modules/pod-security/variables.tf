variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "application_namespaces" {
  type = list(string)
}

variable "pod_security_standards" {
  type    = map(string)
  default = { enforce = "restricted", audit = "restricted", warn = "restricted" }
}

variable "namespace_cpu_request_limit" {
  type    = string
  default = "4"
}

variable "namespace_cpu_limit" {
  type    = string
  default = "8"
}

variable "namespace_memory_request_limit" {
  type    = string
  default = "4Gi"
}

variable "namespace_memory_limit" {
  type    = string
  default = "8Gi"
}

variable "namespace_pod_limit" {
  type    = string
  default = "50"
}
