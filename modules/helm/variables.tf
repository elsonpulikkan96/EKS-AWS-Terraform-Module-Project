variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "domain_name" {
  type    = string
  default = "lucintelsolutions.online"
}

variable "alb_controller_role_arn" {
  type = string
}
