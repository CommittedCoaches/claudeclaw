terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "committed-coaches-terraform-state"
    key          = "claudeclaw/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "claudeclaw"
      ManagedBy = "terraform"
    }
  }
}

# --- Data Sources ---

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.private_subnet_ids
  }
}

# --- Shared Platform Secrets (same keys for all devs) ---

resource "aws_secretsmanager_secret" "shared_platform_keys" {
  name        = "claudeclaw/shared-platform-keys"
  description = "Shared API keys for Close, GHL, GrowthBook, and other platforms"
}

# Populate after first apply:
#   aws secretsmanager put-secret-value --secret-id claudeclaw/shared-platform-keys \
#     --secret-string '{"CLOSE_API_KEY":"...","GHL_API_KEY":"...","GROWTHBOOK_API_KEY":"..."}'

# --- Developer Module (one per dev) ---

# Shared secrets that all dev instances can read
locals {
  shared_secret_arns = [
    aws_secretsmanager_secret.shared_platform_keys.arn,
    # Close
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:CloseAPI-*",
    # GHL
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:GHL_OAUTH-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:GHL_PITS-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:ghl-oauth/config-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:ghl-oauth-proxy/credentials-*",
    # GrowthBook
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:GROWTHBOOK_SDK_KEY-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:/distribution/config/GROWTHBOOK_API_KEY-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:/distribution/config/GROWTHBOOK_SDK_KEY-*",
    # Five9
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:airflow/five9-credentials-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:FIVE9_USERNAME-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:FIVE9_PASSWORD-*",
    # Databases (read-only)
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:RODatabaseAccess-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:DataWarehouseRW-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:airflow/redshift-credentials-*",
    # Slack
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:airflow/slack-bot-tokens-*",
    "arn:aws:secretsmanager:us-east-2:975050128771:secret:airflow/slack-webhooks-*",
  ]
}

module "developer" {
  source   = "./modules/developer"
  for_each = var.developers

  dev_name              = each.key
  instance_type         = each.value.instance_type
  vpc_id                = var.vpc_id
  subnet_id             = var.private_subnet_ids[index(keys(var.developers), each.key) % length(var.private_subnet_ids)]
  repo_url              = var.repo_url
  telegram_token        = each.value.telegram_token
  telegram_user_ids     = each.value.telegram_user_ids
  github_username       = each.value.github_username
  slack_user_id         = each.value.slack_user_id
  slack_token           = each.value.slack_token
  shared_env_secret_arn = aws_secretsmanager_secret.shared_platform_keys.arn
  shared_secret_arns    = local.shared_secret_arns
  iam_policy_arns       = each.value.iam_policy_arns
  clone_repos           = distinct(concat(var.shared_repos, each.value.extra_repos))
}

# --- Security Module ---

module "security" {
  source     = "./modules/security"
  account_id = var.account_id
}
