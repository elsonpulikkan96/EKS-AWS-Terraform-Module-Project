terraform {
  backend "s3" {
    key     = "eks-cluster/terraform.tfstate"
    encrypt = true
  }
}
