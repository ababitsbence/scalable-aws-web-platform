output "app_server_ids" {
  value = aws_instance.app_server[*].id
}

output "app_server_private_ips" {
  value = aws_instance.app_server[*].private_ip
}