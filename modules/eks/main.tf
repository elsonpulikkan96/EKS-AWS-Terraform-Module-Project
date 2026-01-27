resource "aws_eks_cluster" "eks" {

  count    = var.is_eks_cluster_enabled == true ? 1 : 0
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = var.security_group_ids
  }


  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = var.cluster_name
    Env  = var.env
  }
}

# OIDC Provider
# Data source for TLS certificate needs to be correct.
# Usually we get the OIDC issuer URL from the cluster and then get the thumbprint.
# ServiceAccount → OIDC token → STS Security Token Service verifies identity → STS Security Token Service issues temp creds → IAM role allows alb ingress controller to create ALB
# 
data "tls_certificate" "eks_certificate" {
  url = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks-oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_certificate.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks_certificate.url
}


# AddOns for EKS Cluster
resource "aws_eks_addon" "eks-addons" {
  for_each      = { for idx, addon in var.addons : idx => addon }
  cluster_name  = aws_eks_cluster.eks[0].name
  addon_name    = each.value.name
  addon_version = each.value.version

  depends_on = [
    aws_eks_node_group.ondemand-node,
    aws_eks_node_group.spot-node
  ]
}

# NodeGroups
resource "aws_eks_node_group" "ondemand-node" {
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster_name}-on-demand-nodes"

  node_role_arn = var.eks_node_role_arn

  scaling_config {
    desired_size = var.desired_capacity_on_demand
    min_size     = var.min_capacity_on_demand
    max_size     = var.max_capacity_on_demand
  }

  subnet_ids = var.subnet_ids

  instance_types = var.ondemand_instance_types
  capacity_type  = "ON_DEMAND"
  labels = {
    type = "ondemand"
  }

  update_config {
    max_unavailable = 1
  }
  tags = {
    "Name" = "${var.cluster_name}-ondemand-nodes"
  }
  tags_all = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "Name"                                      = "${var.cluster_name}-ondemand-nodes"
  }

  depends_on = [aws_eks_cluster.eks]
}

resource "aws_eks_node_group" "spot-node" {
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster_name}-spot-nodes"

  node_role_arn = var.eks_node_role_arn

  scaling_config {
    desired_size = var.desired_capacity_spot
    min_size     = var.min_capacity_spot
    max_size     = var.max_capacity_spot
  }

  subnet_ids = var.subnet_ids

  instance_types = var.spot_instance_types
  capacity_type  = "SPOT"

  update_config {
    max_unavailable = 1
  }
  tags = {
    "Name" = "${var.cluster_name}-spot-nodes"
  }
  tags_all = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned" # The resource is created and managed specifically for this cluster. If the cluster is deleted, these resources should be cleaned up.
    "Name"                                      = "${var.cluster_name}-ondemand-nodes"
  }

  # "shared": The resource can be used by multiple clusters (less common for node groups, more for subnets/VPCs).

  labels = {
    type      = "spot"
    lifecycle = "spot"
  }
  disk_size = 50

  depends_on = [aws_eks_cluster.eks]
}
