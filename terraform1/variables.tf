variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}


output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "ecr_patient_repo_url" {
  value = aws_ecr_repository.patient.repository_url
}

output "ecr_appointment_repo_url" {
  value = aws_ecr_repository.appointment.repository_url
}

output "lb_dns_name" {
  value = aws_lb.main.dns_name
}