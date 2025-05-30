output "public_subnet_ids" {
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

output "load_balancer_dns" {
  value = aws_lb.main.dns_name
}