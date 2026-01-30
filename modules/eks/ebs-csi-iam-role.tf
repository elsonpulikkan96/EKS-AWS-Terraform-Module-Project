# EBS CSI Driver OIDC IAM Role
# Created here because it needs the OIDC provider which is created in this module

resource "aws_iam_role" "ebs_csi_driver_role" {
  count = var.is_eks_cluster_enabled ? 1 : 0
  name  = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks-oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks-oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_iam_openid_connect_provider.eks-oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.common_tags

  depends_on = [aws_iam_openid_connect_provider.eks-oidc]
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  count      = var.is_eks_cluster_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role[0].name
}
