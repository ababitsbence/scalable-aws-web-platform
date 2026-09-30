resource "tls_private_key" "bastion" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "local_sensitive_file" "bastion_private_key" {
  content         = tls_private_key.bastion.private_key_openssh
  filename        = "${path.module}/bastion-key"
  file_permission = "0600"
}

module "ecr" {
  source    = "./modules/ecr"
  repo_name = var.ecr_repo_name
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  admin_ip     = var.admin_ip
  db_port      = var.db_port
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
}

module "compute" {
  source                = "./modules/compute"
  project_name          = var.project_name
  aws_region            = var.aws_region
  app_subnet_ids        = module.vpc.app_subnet_ids
  app_sg_id             = module.security.app_sg_id
  instance_profile_name = module.iam.instance_profile_name
  ecr_image_url         = "${module.ecr.repository_url}:latest"
  instance_type         = var.instance_type
  key_name              = aws_key_pair.bastion.key_name
}

module "nlb" {
  source            = "./modules/nlb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_server_ids    = module.compute.app_server_ids
  app_sg_id         = module.security.app_sg_id
  nlb_sg_id         = module.security.nlb_sg_id
}

module "bastion" {
  source            = "./modules/bastion"
  project_name      = var.project_name
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security.bastion_sg_id
  instance_type     = var.instance_type
  key_name          = aws_key_pair.bastion.key_name
}