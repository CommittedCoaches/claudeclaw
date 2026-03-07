output "litellm_alb_dns" {
  description = "Internal ALB DNS name for LiteLLM proxy"
  value       = module.litellm.alb_dns_name
}

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

output "litellm_health_check" {
  description = "Command to check LiteLLM health (run from within VPC)"
  value       = "curl http://${module.litellm.alb_dns_name}:4000/health"
}

output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions deploy workflow — set as AWS_DEPLOY_ROLE_ARN secret in GitHub"
  value       = module.security.github_deploy_role_arn
}
