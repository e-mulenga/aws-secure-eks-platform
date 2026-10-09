variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "control_plane_subnet_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "cluster_endpoint_private_access" {
  type    = bool
  default = true
}

variable "cluster_endpoint_public_access" {
  type    = bool
  default = false
}

variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
  default = []
}

variable "cluster_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "account_id" {
  type = string
}

variable "partition" {
  type    = string
  default = "aws"
}

variable "pipeline_role_arn" {
  type    = string
  default = ""
}

variable "addons" {
  type    = map(string)
  default = {}
}
