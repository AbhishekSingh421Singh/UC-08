provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "us-east-1c"
}

resource "aws_ecs_cluster" "main" {
  name = "simple-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole1" # Changed to avoid conflict
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecr_repository" "patient" {
  name = "patient-repo"
}

resource "aws_ecr_repository" "appointment" {
  name = "appointment-repo"
}

resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "main-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}
# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create a route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate public_1 subnet with the route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate public_2 subnet with the route table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}


# ECS Task Definitions
resource "aws_ecs_task_definition" "patient" {
  family                   = "patient-task"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn      = aws_iam_role.ecs_task_execution.arn
  container_definitions   = file("../container-def-patient.json")
}

resource "aws_ecs_task_definition" "appointment" {
  family                   = "appointment-task"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn      = aws_iam_role.ecs_task_execution.arn
  container_definitions   = file("../container-def-appointment.json")
}

# Target Groups
resource "aws_lb_target_group" "patient" {
  name     = "patient-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_target_group" "appointment" {
  name     = "appointment-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
}

# Listeners
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Default response"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "patient" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.patient.arn
  }

  condition {
    path_pattern {
      values = ["/patient*"]
    }
  }
}

resource "aws_lb_listener_rule" "appointment" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.appointment.arn
  }

  condition {
    path_pattern {
      values = ["/appointment*"]
    }
  }
}

# ECS Services
resource "aws_ecs_service" "patient" {
  name            = "patient"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.patient.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.lb_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.patient.arn
    container_name   = "patient-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener_rule.patient]
}

resource "aws_ecs_service" "appointment" {
  name            = "appointment"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.appointment.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.lb_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.appointment.arn
    container_name   = "appointment-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener_rule.appointment]
}