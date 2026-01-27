resource "helm_release" "prometheus-helm" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "81.0.0"
  namespace        = "prometheus"
  create_namespace = true
  cleanup_on_fail  = true
  recreate_pods    = true
  replace          = true

  timeout = 2000

  set {
    name  = "podSecurityPolicy.enabled"
    value = true
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = true
  }

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "prometheus.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "prometheus.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }
}

data "kubernetes_service_v1" "prometheus_server" {
  metadata {
    name      = "prometheus-kube-prometheus-prometheus"
    namespace = "prometheus"
  }
}

data "kubernetes_service_v1" "grafana_server" {
  metadata {
    name      = "prometheus-grafana"
    namespace = "prometheus"
  }
}
