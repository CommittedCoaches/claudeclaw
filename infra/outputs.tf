output "developer_instances" {
  description = "Map of developer name to EC2 instance ID"
  value = {
    for name, dev in module.developer : name => dev.instance_id
  }
}

output "ssm_connect_commands" {
  description = "SSM Session Manager connect commands for each developer"
  value = {
    for name, dev in module.developer : name => "aws ssm start-session --target ${dev.instance_id}"
  }
}

output "onboard_commands" {
  description = "Onboarding commands for each developer (share with them)"
  value = {
    for name, dev in module.developer : name => "./scripts/onboard-dev.sh ${dev.instance_id}"
  }
}

output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions deploy workflow — set as AWS_DEPLOY_ROLE_ARN secret in GitHub"
  value       = module.security.github_deploy_role_arn
}

output "github_terraform_role_arn" {
  description = "IAM role ARN for GitHub Actions terraform apply — set as AWS_TERRAFORM_ROLE_ARN secret in GitHub"
  value       = module.security.github_terraform_role_arn
}

output "github_secrets_role_arn" {
  description = "IAM role ARN for GitHub Actions set-dev-secrets — set as AWS_SECRETS_ROLE_ARN secret in GitHub"
  value       = module.security.github_secrets_role_arn
}
