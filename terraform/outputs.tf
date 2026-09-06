output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "nlb_dns_name" {
  value = module.nlb.dns_name
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}