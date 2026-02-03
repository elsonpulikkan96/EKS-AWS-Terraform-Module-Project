resource "aws_security_group" "eks-cluster-sg" {
  name        = "eks-cluster-sg-${var.env}"
  description = "Security group for EKS cluster control plane communication"

  vpc_id = var.vpc_id

  # Allow all traffic within the cluster security group (node-to-node)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow 443 from worker nodes (managed by EKS)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow worker nodes to communicate with control plane"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "eks-cluster-sg-${var.env}"
  })
}

resource "aws_security_group" "bastion-sg" {
  name        = "bastion-sg-${var.env}"
  description = "Allow SSH to Bastion"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "bastion-sg-${var.env}"
  })
}
