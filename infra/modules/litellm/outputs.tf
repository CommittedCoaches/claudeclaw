output "alb_dns_name" {
  description = "DNS name of the internal ALB for LiteLLM"
  value       = aws_lb.litellm.dns_name
}

output "alb_security_group_id" {
  description = "Security group ID of the LiteLLM ALB"
  value       = aws_security_group.alb.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.litellm.name
}
