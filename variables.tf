
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

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to access EKS public API endpoint. REQUIRED for each environment."
}
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
    version = optional(string) # Make version optional
  }))
  description = "List of EKS addons to install. Version is optional - if not specified, AWS will use the default compatible version."
}

# Bastion
variable "bastion_image_id" {
  type        = string
  default     = null
  description = "AMI ID for bastion host. If not provided, uses latest Ubuntu 24.04 LTS for the region."
}

variable "bastion_instance_type" {
  type = string
}

variable "bastion_tags" {
  type = map(string)
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
}
