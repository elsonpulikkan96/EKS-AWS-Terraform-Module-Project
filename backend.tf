terraform {
  backend "s3" {
    bucket         = "spectrio-eks-terraform-state"
    key            = "eks-cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "spectrio-eks-terraform-locks"
    encrypt        = true
    
    # Workspace-specific state files will be stored as:
    # env:/dev/eks-cluster/terraform.tfstate
    # env:/stage/eks-cluster/terraform.tfstate
    # env:/prod/eks-cluster/terraform.tfstate
  }
}
