
output "bastion_public_ip" {
  value = module.bastion.bastion_public_ip
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
