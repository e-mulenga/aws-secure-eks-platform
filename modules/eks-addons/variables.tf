variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "enable_aws_load_balancer_controller" {
  type    = bool
  default = true
}

variable "alb_controller_role_arn" {
  type    = string
  default = ""
}

variable "enable_cluster_autoscaler" {
  type    = bool
  default = true
}

variable "cluster_autoscaler_role_arn" {
  type    = string
  default = ""
}

variable "enable_metrics_server" {
  type    = bool
  default = true
}

variable "enable_external_secrets" {
  type    = bool
  default = true
}

variable "external_secrets_role_arn" {
  type    = string
  default = ""
}

variable "enable_falco" {
  type    = bool
  default = true
}

variable "alarm_sns_topic_arn" {
  type    = string
  default = ""
}
