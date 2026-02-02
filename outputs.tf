
output "bastion_public_ip" {
  value = module.bastion.bastion_public_ip
}

output "ssh_key_name" {
  value       = aws_key_pair.eks_key.key_name
  description = "Auto-generated SSH key pair name (format: eks-<env>-<account_id>)"
}

output "ssh_private_key_path" {
  description = "Path to the generated private key file"
  value       = "${path.module}/${local.key_name}.pem"
  sensitive   = true
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "region" {
  value = var.region
}

output "argocd_url" {
  value = module.helm.argocd_url
}

output "prometheus_url" {
  value = module.helm.prometheus_url
}

output "grafana_url" {
  value = module.helm.grafana_url
}
