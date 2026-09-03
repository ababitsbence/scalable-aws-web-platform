module "ecr" {
  source    = "./modules/ecr"
  repo_name = var.ecr_repo_name
}