output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.dev.id
}

output "security_group_id" {
  description = "Security group ID for this developer instance"
  value       = aws_security_group.dev.id
}
