output "redis_endpoint" {
  value       = var.create ? aws_elasticache_cluster.redis[0].cache_nodes[0].address : ""
  description = "Redis primary endpoint address"
}

output "redis_port" {
  value       = var.create ? aws_elasticache_cluster.redis[0].cache_nodes[0].port : 6379
  description = "Redis port"
}

output "redis_connection_string" {
  value       = var.create ? "${aws_elasticache_cluster.redis[0].cache_nodes[0].address}:${aws_elasticache_cluster.redis[0].cache_nodes[0].port}" : "redis-cart:6379"
  description = "Full Redis connection string (host:port)"
}

output "security_group_id" {
  value       = aws_security_group.redis.id
  description = "Security group ID of the Redis cluster"
}
