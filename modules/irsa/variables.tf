variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "account_id" {
  type = string
}

variable "partition" {
  type    = string
  default = "aws"
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "enable_alb_controller" {
  type    = bool
  default = true
}

variable "enable_cluster_autoscaler" {
  type    = bool
  default = true
}

variable "enable_external_secrets" {
  type    = bool
  default = true
}

variable "enable_ebs_csi" {
  type    = bool
  default = true
}

variable "enable_container_insights" {
  type    = bool
  default = true
}
