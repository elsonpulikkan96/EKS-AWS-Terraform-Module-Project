variable "env" {
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
  type        = string
  description = "Cluster name to tag subnets for Karpenter/ALB discovery"
}
