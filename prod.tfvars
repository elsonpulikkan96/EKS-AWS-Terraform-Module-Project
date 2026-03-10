env            = "production"
region         = "us-east-1"
vpc_cidr_block = "10.2.0.0/16"

public_subnet  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet = ["10.2.4.0/24", "10.2.5.0/24", "10.2.6.0/24"]



# EKS
is_eks_cluster_enabled  = true
cluster_version         = "1.33"
cluster_name            = "prod-eks-cluster"
endpoint_private_access = true
endpoint_public_access  = true
# SECURITY: Restrict to your organization's IP ranges or VPN CIDR
# Example: ["203.0.113.0/24", "198.51.100.0/24"]
public_access_cidrs     = ["103.184.238.201/32"]  # Current IP updated
authentication_mode     = "API_AND_CONFIG_MAP"

ondemand_instance_types = ["t3a.large"]
spot_instance_types     = ["c5a.large", "c5a.xlarge", "m5a.large", "m5a.xlarge", "c5.large", "m5.large", "t3a.large", "t3a.xlarge"]

desired_capacity_on_demand = "2"
min_capacity_on_demand     = "2"
max_capacity_on_demand     = "5"

desired_capacity_spot = "2"
min_capacity_spot     = "2"
max_capacity_spot     = "4"

addons = [
  {
    name    = "vpc-cni"
    version = "v1.21.1-eksbuild.3"
  },
  {
    name    = "coredns"
    version = "v1.13.2-eksbuild.1"
  },
  {
    name    = "kube-proxy"
    version = "v1.33.8-eksbuild.4"
  },
  {
    name    = "aws-efs-csi-driver"
    version = "v2.3.0-eksbuild.2"
  },
  {
    name    = "aws-ebs-csi-driver"
    version = "v1.56.0-eksbuild.1"
  }
]



#BASTION
# bastion_image_id is optional - will auto-detect latest Ubuntu 24.04 LTS for your region
bastion_instance_type = "t2.small"
bastion_tags          = { Name = "bastion-prod" }

tags = {
  Project     = "vpc-alb"
  Environment = "production"
}
