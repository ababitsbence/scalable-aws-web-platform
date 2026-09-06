output "dns_name" {
  value = aws_lb.app.dns_name
}

output "arn" {
  value = aws_lb.app.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}