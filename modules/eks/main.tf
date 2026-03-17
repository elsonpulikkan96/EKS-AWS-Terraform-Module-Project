resource "aws_eks_cluster" "eks" {

  count    = var.is_eks_cluster_enabled == true ? 1 : 0
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
    security_group_ids      = var.security_group_ids
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  timeouts {
    create = "30m"
    update = "45m"
    delete = "30m"
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
    Env  = var.env
  })
}

# OIDC Provider
data "tls_certificate" "eks_certificate" {
  url = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks-oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_certificate.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks_certificate.url

  lifecycle {
    ignore_changes = [thumbprint_list]
  }
}


# Resolve latest compatible addon versions when not pinned
data "aws_eks_addon_version" "addons" {
  for_each           = { for addon in var.addons : addon.name => addon }
  addon_name         = each.value.name
  kubernetes_version = aws_eks_cluster.eks[0].version

  depends_on = [aws_eks_cluster.eks]
}

# AddOns — depend on cluster AND node groups so pods can schedule
resource "aws_eks_addon" "eks-addons" {
  for_each     = { for addon in var.addons : addon.name => addon }
  cluster_name = aws_eks_cluster.eks[0].name
  addon_name   = each.value.name

  # If version is pinned use it, otherwise use the latest compatible default
  addon_version = coalesce(lookup(each.value, "version", null), data.aws_eks_addon_version.addons[each.key].version)

  service_account_role_arn = each.value.name == "aws-ebs-csi-driver" ? aws_iam_role.ebs_csi_driver_role[0].arn : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  timeouts {
    create = "20m"
    update = "20m"
    delete = "15m"
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role.ebs_csi_driver_role,
    aws_eks_node_group.ondemand-node,
  ]
}

# Launch Template for On-Demand Nodes
resource "aws_launch_template" "ondemand" {
  name_prefix = "${var.cluster_name}-ondemand-"
  description = "EKS ${var.cluster_version} ondemand nodes"
  key_name    = var.node_key_name

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
      "Name"                                      = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      "Name" = "${var.cluster_name}-ondemand-volume"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# NodeGroups
resource "aws_eks_node_group" "ondemand-node" {
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster_name}-on-demand-nodes"
  version         = aws_eks_cluster.eks[0].version

  node_role_arn        = var.eks_node_role_arn
  force_update_version = true

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
    version = aws_launch_template.ondemand.latest_version
  }

  update_config {
    max_unavailable = 1
  }

  timeouts {
    create = "30m"
    update = "60m"
    delete = "30m"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  tags = merge(var.common_tags, {
    "Name"                                      = "${var.cluster_name}-ondemand-nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  depends_on = [aws_eks_cluster.eks]
}

# Launch Template for Spot Nodes
resource "aws_launch_template" "spot" {
  name_prefix = "${var.cluster_name}-spot-"
  description = "EKS ${var.cluster_version} spot nodes"
  key_name    = var.node_key_name

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
      "Name"                                      = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      "Name" = "${var.cluster_name}-spot-volume"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "spot-node" {
  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster_name}-spot-nodes"
  version         = aws_eks_cluster.eks[0].version

  node_role_arn        = var.eks_node_role_arn
  force_update_version = true

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
    version = aws_launch_template.spot.latest_version
  }

  timeouts {
    create = "30m"
    update = "60m"
    delete = "30m"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  tags = merge(var.common_tags, {
    "Name"                                      = "${var.cluster_name}-spot-nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  # Spot upgrades after on-demand is healthy
  depends_on = [aws_eks_cluster.eks, aws_eks_node_group.ondemand-node]
}
