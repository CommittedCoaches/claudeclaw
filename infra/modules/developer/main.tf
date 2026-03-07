# --- AMI: Ubuntu 24.04 LTS ---

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Security Group ---

resource "aws_security_group" "dev" {
  name_prefix = "claudeclaw-dev-${var.dev_name}-"
  vpc_id      = var.vpc_id
  description = "ClaudeClaw dev instance for ${var.dev_name} - no ingress (SSM only)"

  # No ingress rules — access via SSM Session Manager only

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

# --- IAM Role ---

resource "aws_iam_role" "dev" {
  name = "claudeclaw-dev-${var.dev_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# SSM core policy for Session Manager access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.dev.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom IAM policies (when iam_policy_arns is specified)
resource "aws_iam_role_policy_attachment" "custom" {
  for_each   = toset(var.iam_policy_arns)
  role       = aws_iam_role.dev.name
  policy_arn = each.value
}

# Default restricted policy for non-admin devs
# Only created when no custom policies are specified
resource "aws_iam_role_policy" "restricted" {
  count = length(var.iam_policy_arns) == 0 ? 1 : 0
  name  = "restricted-access"
  role  = aws_iam_role.dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
        ]
        Resource = "*"
      },
      {
        Sid    = "MWAAReadAndTrigger"
        Effect = "Allow"
        Action = [
          "airflow:GetEnvironment",
          "airflow:ListEnvironments",
          "airflow:CreateWebLoginToken",
          "airflow:CreateCliToken",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListPolicies",
          "iam:ListRoles",
          "iam:GetUser",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListGroupsForUser",
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
        ]
        Resource = "*"
      },
      {
        Sid    = "SharedPlatformSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = var.shared_secret_arns
      },
    ]
  })
}

# When custom policies are used, still grant Secrets Manager access for shared keys
resource "aws_iam_role_policy" "shared_secrets" {
  count = length(var.iam_policy_arns) > 0 ? 1 : 0
  name  = "shared-platform-secrets"
  role  = aws_iam_role.dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.shared_secret_arns
    }]
  })
}

resource "aws_iam_instance_profile" "dev" {
  name = "claudeclaw-dev-${var.dev_name}"
  role = aws_iam_role.dev.name
}

# --- EC2 Instance ---

resource "aws_instance" "dev" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.dev.name
  vpc_security_group_ids = [aws_security_group.dev.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    dev_name                   = var.dev_name
    repo_url                   = var.repo_url
    litellm_alb_dns            = var.litellm_alb_dns
    telegram_token             = var.telegram_token
    telegram_user_ids          = jsonencode(var.telegram_user_ids)
    slack_user_id              = var.slack_user_id
    slack_token                = var.slack_token
    shared_platform_secret_arn = var.shared_env_secret_arn
    github_username            = var.github_username
    clone_repos                = jsonencode(var.clone_repos)
  })

  tags = {
    Name = "claudeclaw-dev-${var.dev_name}"
  }
}
