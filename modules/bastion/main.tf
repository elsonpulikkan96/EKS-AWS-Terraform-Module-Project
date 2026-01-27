resource "aws_instance" "bastion" {
  ami                    = var.image_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_groups
  tags                   = var.tags
  key_name               = var.key_name
  user_data              = var.user_data
  iam_instance_profile   = var.iam_instance_profile_name
}
