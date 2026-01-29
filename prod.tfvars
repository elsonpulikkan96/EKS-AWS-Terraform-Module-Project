env            = "production"
region         = "us-east-1"
vpc_cidr_block = "10.2.0.0/16"

public_subnet  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet = ["10.2.4.0/24", "10.2.5.0/24", "10.2.6.0/24"]



# EKS
is_eks_cluster_enabled  = true
cluster_version         = "1.35"
cluster_name            = "spectrio-prod-eks-cluster"
endpoint_private_access = true
endpoint_public_access  = false
authentication_mode     = "API_AND_CONFIG_MAP"

ondemand_instance_types = ["t3a.large"]
spot_instance_types     = ["c5a.large", "c5a.xlarge", "m5a.large", "m5a.xlarge", "c5.large", "m5.large", "t3a.large", "t3a.xlarge"]

desired_capacity_on_demand = "2"
min_capacity_on_demand     = "2"
max_capacity_on_demand     = "5"

desired_capacity_spot = "3"
min_capacity_spot     = "3"
max_capacity_spot     = "20"

addons = [
  {
    name = "vpc-cni"
    # Version omitted - AWS will auto-select compatible version for EKS 1.35
  },
  {
    name = "coredns"
    # Version omitted - AWS will auto-select compatible version for EKS 1.35
  },
  {
    name = "kube-proxy"
    # Version omitted - AWS will auto-select compatible version for EKS 1.35
  },
  {
    name = "aws-efs-csi-driver"
    # Version omitted - AWS will auto-select compatible version for EKS 1.35
  },
  {
    name = "aws-ebs-csi-driver"
    # Version omitted - AWS will auto-select compatible version for EKS 1.35
  }

]



#BASTION
bastion_image_id      = "ami-0b6c6ebed2801a5cb" # Ubuntu 24.04 LTS for us-east-1
bastion_instance_type = "t2.small"
bastion_tags          = { Name = "bastion-prod" }
bastion_key_name      = "tf-bastion-eks-project" # create your own key pair

tags = {
  Project     = "vpc-alb"
  Environment = "production"
}
