variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "node_ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size_gb   = number
    labels         = map(string)
    taints         = list(map(string))
  }))
}
