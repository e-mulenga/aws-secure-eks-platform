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

variable "enable_container_insights" {
  type    = bool
  default = true
}

variable "container_insights_role_arn" {
  type    = string
  default = ""
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "kms_key_arn" {
  type = string
}

variable "alarm_sns_topic_arn" {
  type    = string
  default = ""
}
