data "aws_caller_identity" "current" {}

resource "random_string" "uid" {
  length  = 6
  special = false
  upper   = false
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  uid        = random_string.uid.result
  key_name   = "eks-${var.env}-${local.account_id}-${local.uid}"
}

resource "aws_key_pair" "eks_key" {
  key_name   = local.key_name
  public_key = tls_private_key.eks_key.public_key_openssh

  tags = merge(var.tags, {
    Name        = local.key_name
    Environment = var.env
    ManagedBy   = "terraform"
  })
}

resource "tls_private_key" "eks_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.eks_key.private_key_pem
  filename        = "${path.module}/${local.key_name}.pem"
  file_permission = "0400"
}
