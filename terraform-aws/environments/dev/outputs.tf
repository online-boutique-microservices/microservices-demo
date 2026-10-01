output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster API endpoint"
}

output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Map of service names to ECR repository URLs"
}

output "redis_connection_string" {
  value       = module.elasticache.redis_connection_string
  description = "Redis connection string for cartservice"
}

output "github_actions_role_arn" {
  value       = module.github_oidc.role_arn
  description = "IAM role ARN for GitHub Actions (set as GitHub secret AWS_ROLE_ARN)"
}

output "configure_kubectl" {
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
  description = "Command to configure kubectl"
}
