output "cluster_endpoint" {
  value = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].endpoint : null
}

output "cluster_name" {
  value = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].name : null
}

output "oidc_provider_url" {
  value = aws_iam_openid_connect_provider.eks-oidc.url
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks-oidc.arn
}

output "cluster_certificate_authority_data" {
  value = var.is_eks_cluster_enabled ? aws_eks_cluster.eks[0].certificate_authority[0].data : null
}
