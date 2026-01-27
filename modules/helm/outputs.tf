output "argocd_url" {
  value = try(data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "prometheus_url" {
  value = try(data.kubernetes_service_v1.prometheus_server.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "grafana_url" {
  value = try(data.kubernetes_service_v1.grafana_server.status[0].load_balancer[0].ingress[0].hostname, "")
}
