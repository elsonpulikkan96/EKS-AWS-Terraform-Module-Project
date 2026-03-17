resource "time_sleep" "wait_for_alb_controller" {
  depends_on      = [helm_release.aws-load-balancer-controller]
  create_duration = "45s"

  triggers = {
    alb_chart_version = helm_release.aws-load-balancer-controller.version
  }
}

resource "helm_release" "prometheus-helm" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "82.10.1"
  namespace        = "prometheus"
  create_namespace = true
  timeout          = 600
  wait             = true

  depends_on = [time_sleep.wait_for_alb_controller]

  # PodSecurityPolicy removed in K8s 1.25+
  set {
    name  = "podSecurityPolicy.enabled"
    value = false
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = true
  }

  set {
    name  = "grafana.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "prometheus.service.type"
    value = "ClusterIP"
  }
}

# Wait for services to be created before reading them
resource "time_sleep" "wait_for_prometheus" {
  depends_on      = [helm_release.prometheus-helm]
  create_duration = "60s"

  triggers = {
    prometheus_chart_version = helm_release.prometheus-helm.version
  }
}

data "kubernetes_service_v1" "prometheus_server" {
  metadata {
    name      = "prometheus-kube-prometheus-prometheus"
    namespace = "prometheus"
  }

  depends_on = [time_sleep.wait_for_prometheus, helm_release.prometheus-helm]
}

data "kubernetes_service_v1" "grafana_server" {
  metadata {
    name      = "prometheus-grafana"
    namespace = "prometheus"
  }

  depends_on = [time_sleep.wait_for_prometheus, helm_release.prometheus-helm]
}
