locals {
  env = var.env
}

module "vpc" {
  source = "./modules/vpc"

  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  public_subnet  = var.public_subnet
  private_subnet = var.private_subnet
  cluster_name   = "${local.env}-${var.cluster_name}"
}

module "sg" {
  source = "./modules/sg"

  env    = var.env
  vpc_id = module.vpc.vpc_id
}

module "iam" {
  source = "./modules/iam"

  cluster_name                  = "${local.env}-${var.cluster_name}"
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true
  is_alb_controller_enabled     = true
  region                        = var.region
  vpc_id                        = module.vpc.vpc_id
  oidc_provider_url             = module.eks.oidc_provider_url
  oidc_provider_arn             = module.eks.oidc_provider_arn

  depends_on = [module.vpc]
}

module "eks" {
  source = "./modules/eks"

  env          = var.env
  cluster_name = "${local.env}-${var.cluster_name}"

  # Input vars from other modules
  subnet_ids           = module.vpc.private_subnets
  security_group_ids   = [module.sg.eks_cluster_sg_id]
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn    = module.iam.eks_nodegroup_role_arn

  is_eks_cluster_enabled     = var.is_eks_cluster_enabled
  cluster_version            = var.cluster_version
  endpoint_private_access    = var.endpoint_private_access
  endpoint_public_access     = var.endpoint_public_access
  authentication_mode        = var.authentication_mode
  ondemand_instance_types    = var.ondemand_instance_types
  spot_instance_types        = var.spot_instance_types
  desired_capacity_on_demand = var.desired_capacity_on_demand
  min_capacity_on_demand     = var.min_capacity_on_demand
  max_capacity_on_demand     = var.max_capacity_on_demand
  desired_capacity_spot      = var.desired_capacity_spot
  min_capacity_spot          = var.min_capacity_spot
  max_capacity_spot          = var.max_capacity_spot
  addons                     = var.addons

  depends_on = [module.vpc]
}

module "bastion" {
  source = "./modules/bastion"

  image_id                  = var.bastion_image_id
  instance_type             = var.bastion_instance_type
  subnet_id                 = module.vpc.public_subnets[0] # Use public subnet for bastion
  security_groups           = [module.sg.bastion_sg_id]
  key_name                  = var.bastion_key_name
  tags                      = var.bastion_tags
  user_data                 = file("bastion_script.sh")
  iam_instance_profile_name = module.iam.bastion_iam_instance_profile_name

  depends_on = [module.vpc]
}

# EKS Access Entry for Bastion
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.bastion_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.bastion_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [module.eks]
}

module "helm" {
  source = "./modules/helm"

  cluster_name            = module.eks.cluster_name
  vpc_id                  = module.vpc.vpc_id
  region                  = var.region
  alb_controller_role_arn = module.iam.alb_controller_role_arn

  depends_on = [module.eks, module.vpc, module.iam]
}
