output "cloudtrail_arn" {
  value = aws_cloudtrail.audit.arn
}

output "mfa_policy_arn" {
  value = aws_iam_policy.mfa_enforcement.arn
}
