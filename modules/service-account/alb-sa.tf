# to create service account for alb controller we need kubernetes provider
resource "kubernetes_service_account" "alb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role.arn
    }
  }
  depends_on = [aws_eks_cluster.my_cluster, aws_eks_node_group.ondemand_nodes]
}
