output "eks_cluster_sg_id" {
  value = aws_security_group.eks-cluster-sg.id
}

output "bastion_sg_id" {
  # Wait, bastion SG was not in sg.tf. It might be missing.
  # Let's check sg.tf content again.
  # I viewed sg.tf in Step 103. It only had eks-cluster-sg.
  # User referenced module.sg.bastion_sg_id in main.tf.
  # If it's not in sg.tf, I need to add it or find where it is.
  # The prompt error earlier didn't complain about missing attribute yet (it failed at init).
  # I will assume I need to ADD bastion_sg to sg module.
  value = aws_security_group.bastion-sg.id
}
