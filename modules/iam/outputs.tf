output "eks_cluster_role_arn" {
  value = var.is_eks_role_enabled ? aws_iam_role.eks-cluster-role[0].arn : null
}

output "eks_nodegroup_role_arn" {
  value = var.is_eks_nodegroup_role_enabled ? aws_iam_role.eks-nodegroup-role[0].arn : null
}

output "bastion_iam_instance_profile_name" {
  value = aws_iam_instance_profile.bastion_profile.name
}

output "bastion_role_arn" {
  value = aws_iam_role.bastion_role.arn
}

output "alb_controller_role_arn" {
  value = var.is_alb_controller_enabled ? aws_iam_role.alb_controller_role[0].arn : null
}
