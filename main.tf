locals {
  env = var.env
  
  common_tags = {
    terraform = "true"
  }
}

module "vpc" {
  source = "./modules/vpc"

  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  public_subnet  = var.public_subnet
  private_subnet = var.private_subnet
  cluster_name   = "${local.env}-${var.cluster_name}"
  common_tags    = local.common_tags
}

module "sg" {
  source = "./modules/sg"

  env         = var.env
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr_block
  common_tags = local.common_tags
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
  common_tags                   = local.common_tags

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
  public_access_cidrs        = var.public_access_cidrs
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
  node_key_name              = aws_key_pair.eks_key.key_name
  common_tags                = local.common_tags

  depends_on = [module.vpc]
}

module "bastion" {
  source = "./modules/bastion"

  image_id                  = coalesce(var.bastion_image_id, data.aws_ami.ubuntu.id)
  instance_type             = var.bastion_instance_type
  subnet_id                 = module.vpc.public_subnets[0]
  security_groups           = [module.sg.bastion_sg_id]
  key_name                  = aws_key_pair.eks_key.key_name
  tags                      = merge(local.common_tags, var.bastion_tags)
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

# Wait for OIDC provider to propagate in IAM
resource "time_sleep" "wait_for_oidc" {
  depends_on      = [module.iam]
  create_duration = "30s"
}

# Wait for cluster and nodes to be ready
resource "null_resource" "wait_for_cluster_ready" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<-EOT
      aws eks wait cluster-active --name ${module.eks.cluster_name} --region ${var.region}
      aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}
      kubectl wait --for=condition=Ready nodes --all --timeout=300s
    EOT
  }
}

module "helm" {
  source = "./modules/helm"

  cluster_name            = module.eks.cluster_name
  vpc_id                  = module.vpc.vpc_id
  region                  = var.region
  alb_controller_role_arn = module.iam.alb_controller_role_arn

  depends_on = [null_resource.wait_for_cluster_ready, time_sleep.wait_for_oidc]
}
