variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for all resources"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets in rds-vpc for ECS, RDS, and dev instances (must span 2+ AZs)"
}

variable "account_id" {
  type        = string
  description = "AWS account ID"
}

variable "developers" {
  type = map(object({
    instance_type      = optional(string, "t3.medium")
    telegram_token     = optional(string, "")
    telegram_user_ids  = optional(list(number), [])
    github_username    = optional(string, "")
    slack_user_id      = optional(string, "")
    iam_policy_arns    = optional(list(string), [])
    extra_repos        = optional(list(string), [])
  }))
  description = "Map of developer name to config. iam_policy_arns overrides the default restricted policy — use [\"arn:aws:iam::aws:policy/AdministratorAccess\"] for admin."
}

variable "shared_repos" {
  type = list(string)
  default = [
    "admin-server",
    "data",
    "cc_utils",
    "booking-calendar-sync",
    "lambda",
    "queue-consumers",
    "control-panel",
    "appointment-distribution",
    "cc_rules",
    "ac-booking-calendar-sync",
    "five9-scripts",
  ]
  description = "Repos cloned on all dev instances"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/CommittedCoaches/claudeclaw.git"
}

