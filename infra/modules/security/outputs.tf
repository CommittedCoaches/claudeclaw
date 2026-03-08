output "cloudtrail_arn" {
  value = aws_cloudtrail.audit.arn
}

output "mfa_policy_arn" {
  value = aws_iam_policy.mfa_enforcement.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_actions_deploy.arn
}

output "github_terraform_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}

output "github_secrets_role_arn" {
  value = aws_iam_role.github_actions_secrets.arn
}
