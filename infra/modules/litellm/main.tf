# --- ECR Repository for custom LiteLLM image ---

resource "aws_ecr_repository" "litellm" {
  name                 = "claudeclaw-litellm"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --- ECS Cluster ---

resource "aws_ecs_cluster" "litellm" {
  name = "claudeclaw-litellm"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "litellm" {
  name              = "/ecs/claudeclaw-litellm"
  retention_in_days = 30
}

# --- Secrets Manager: LiteLLM master key + DB password ---

resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
}

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "litellm_master_key" {
  name = "claudeclaw/litellm-master-key"
}

resource "aws_secretsmanager_secret_version" "litellm_master_key" {
  secret_id     = aws_secretsmanager_secret.litellm_master_key.id
  secret_string = "sk-${random_password.litellm_master_key.result}"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "claudeclaw/litellm-db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_secretsmanager_secret" "db_url" {
  name = "claudeclaw/litellm-db-url"
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql://litellm:${random_password.db_password.result}@${aws_db_instance.litellm.endpoint}/litellm"
}

# --- RDS PostgreSQL ---

resource "aws_db_subnet_group" "litellm" {
  name       = "claudeclaw-litellm"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "litellm" {
  identifier     = "claudeclaw-litellm"
  engine         = "postgres"
  engine_version = "16.13"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_encrypted     = true

  db_name  = "litellm"
  username = "litellm"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.litellm.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  multi_az            = false

  backup_retention_period = 7
}

# --- Security Groups ---

resource "aws_security_group" "alb" {
  name_prefix = "claudeclaw-litellm-alb-"
  vpc_id      = var.vpc_id
  description = "ALB for LiteLLM proxy - ingress rules added by root module"

  # Ingress rules added externally via aws_security_group_rule to avoid
  # a dependency cycle between litellm and developer modules.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs" {
  name_prefix = "claudeclaw-litellm-ecs-"
  vpc_id      = var.vpc_id
  description = "ECS tasks for LiteLLM - ingress from ALB only"

  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "claudeclaw-litellm-rds-"
  vpc_id      = var.vpc_id
  description = "RDS for LiteLLM - ingress from ECS only"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Internal ALB ---

resource "aws_lb" "litellm" {
  name               = "claudeclaw-litellm"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids
}

resource "aws_lb_target_group" "litellm" {
  name        = "claudeclaw-litellm"
  port        = 4000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health/liveliness"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
  }
}

resource "aws_lb_listener" "litellm" {
  load_balancer_arn = aws_lb.litellm.arn
  port              = 4000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.litellm.arn
  }
}

# --- IAM Role for ECS Task ---

resource "aws_iam_role" "ecs_task_execution" {
  name = "claudeclaw-litellm-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_secrets" {
  name = "secrets-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        aws_secretsmanager_secret.litellm_master_key.arn,
        aws_secretsmanager_secret.db_password.arn,
        aws_secretsmanager_secret.db_url.arn,
      ]
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "claudeclaw-litellm-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# --- ECS Task Definition ---

resource "aws_ecs_task_definition" "litellm" {
  family                   = "claudeclaw-litellm"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "litellm"
    image     = "${aws_ecr_repository.litellm.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 4000
      protocol      = "tcp"
    }]

    command = ["--config", "/app/config.yaml", "--port", "4000"]

    secrets = [
      {
        name      = "LITELLM_MASTER_KEY"
        valueFrom = aws_secretsmanager_secret.litellm_master_key.arn
      },
      {
        name      = "DATABASE_URL"
        valueFrom = aws_secretsmanager_secret.db_url.arn
      },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.litellm.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "litellm"
      }
    }
  }])
}

data "aws_region" "current" {}

# --- ECS Service ---

resource "aws_ecs_service" "litellm" {
  name            = "claudeclaw-litellm"
  cluster         = aws_ecs_cluster.litellm.id
  task_definition = aws_ecs_task_definition.litellm.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.litellm.arn
    container_name   = "litellm"
    container_port   = 4000
  }

  depends_on = [aws_lb_listener.litellm]
}

# --- VPC Endpoint Security Group ---
# The VPC already has endpoints for secretsmanager, ecr.api, ecr.dkr, s3, and logs.
# This SG is added to the existing endpoints (e.g. secretsmanager) to allow
# Fargate tasks to reach them over HTTPS.

data "aws_vpc" "main" {
  id = var.vpc_id
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "claudeclaw-vpce-"
  vpc_id      = var.vpc_id
  description = "Allow HTTPS from VPC CIDR to VPC endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
