output "public_subnet_1_id" {
  value = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_2.id
}

output "load_balancer_dns" {
  value = aws_lb.main.dns_name
}