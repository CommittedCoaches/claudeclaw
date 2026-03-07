output "cloudtrail_arn" {
  value = aws_cloudtrail.audit.arn
}

output "mfa_policy_arn" {
  value = aws_iam_policy.mfa_enforcement.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_actions_deploy.arn
}
