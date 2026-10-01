output "repository_urls" {
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
  description = "Map of service name to ECR repository URL"
}

output "registry_id" {
  value       = values(aws_ecr_repository.services)[0].registry_id
  description = "The account ID of the ECR registry"
}
