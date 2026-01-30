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

  tags = merge(var.common_tags, {
    Name = var.cluster_name
    Env  = var.env
  })
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
  addon_version = lookup(each.value, "version", null)

  # EBS CSI driver requires dedicated OIDC service account role
  service_account_role_arn = each.value.name == "aws-ebs-csi-driver" ? aws_iam_role.ebs_csi_driver_role[0].arn : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [
    aws_eks_node_group.ondemand-node,
    aws_eks_node_group.spot-node,
    aws_iam_role.ebs_csi_driver_role
  ]
}

# Launch Template for On-Demand Nodes
resource "aws_launch_template" "ondemand" {
  name_prefix = "${var.cluster_name}-ondemand-"
  key_name    = var.node_key_name
  
  user_data = base64encode(file("${path.module}/ssm-userdata.sh"))
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      "Name" = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      "Name" = "${var.cluster_name}-ondemand-volume"
    })
  }
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

  launch_template {
    id      = aws_launch_template.ondemand.id
    version = "$Latest"
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.common_tags, {
    "Name" = "${var.cluster_name}-ondemand-nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  depends_on = [aws_eks_cluster.eks]
}

# Launch Template for Spot Nodes
resource "aws_launch_template" "spot" {
  name_prefix = "${var.cluster_name}-spot-"
  key_name    = var.node_key_name
  
  user_data = base64encode(file("${path.module}/ssm-userdata.sh"))
  
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
      volume_type = "gp3"
    }
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      "Name" = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      "Name" = "${var.cluster_name}-spot-volume"
    })
  }
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

  labels = {
    type      = "spot"
    lifecycle = "spot"
  }

  launch_template {
    id      = aws_launch_template.spot.id
    version = "$Latest"
  }

  tags = merge(var.common_tags, {
    "Name" = "${var.cluster_name}-spot-nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  depends_on = [aws_eks_cluster.eks]
}
