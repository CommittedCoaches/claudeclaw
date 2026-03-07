variable "dev_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9_-]+$", var.dev_name))
    error_message = "dev_name must contain only lowercase letters, digits, hyphens, and underscores."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "litellm_alb_dns" {
  type = string
}

variable "repo_url" {
  type = string
}

variable "telegram_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "telegram_user_ids" {
  type    = list(number)
  default = []
}

variable "github_username" {
  type    = string
  default = ""
}

variable "slack_user_id" {
  type    = string
  default = ""
}

variable "slack_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "shared_env_secret_arn" {
  type        = string
  description = "ARN of the shared env secret (loaded into env file on boot)"
}

variable "shared_secret_arns" {
  type        = list(string)
  description = "ARNs of all shared secrets the dev instances can read"
}

variable "iam_policy_arns" {
  type        = list(string)
  default     = []
  description = "Custom IAM policy ARNs to attach. When set, replaces the default restricted policy. Use for admin or custom permissions."
}

variable "clone_repos" {
  type        = list(string)
  default     = []
  description = "List of repo names (under CommittedCoaches org) to clone on instance boot"
}
