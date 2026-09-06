data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ecr_registry = split("/", var.ecr_image_url)[0]
}

resource "aws_instance" "app_server" {
  count = length(var.app_subnet_ids)

  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.app_subnet_ids[count.index]
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region    = var.aws_region
    ecr_registry  = local.ecr_registry
    ecr_image_url = var.ecr_image_url
  })

  tags = {
    Name = "${var.project_name}-app-server-${count.index}"
  }
}