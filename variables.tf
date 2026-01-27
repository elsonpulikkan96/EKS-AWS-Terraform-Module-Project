
variable "region" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "public_subnet" {
  type = list(string)
}
variable "private_subnet" {
  type = list(string)
}

variable "cluster_name" {
  type = string
}

variable "env" {
  type = string
}

# EKS
variable "is_eks_cluster_enabled" {}
variable "cluster_version" {}
variable "endpoint_private_access" {}
variable "endpoint_public_access" {}
variable "authentication_mode" {}

variable "ondemand_instance_types" {}
variable "spot_instance_types" {}
variable "desired_capacity_on_demand" {}
variable "min_capacity_on_demand" {}
variable "max_capacity_on_demand" {}
variable "desired_capacity_spot" {}
variable "min_capacity_spot" {}
variable "max_capacity_spot" {}
variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
}

# Bastion
variable "bastion_image_id" {
  type = string
}

variable "bastion_instance_type" {
  type = string
}

variable "bastion_key_name" {
  type = string
}

variable "bastion_tags" {
  type = map(string)
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
}
