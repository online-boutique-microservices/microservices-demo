variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where Redis will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the ElastiCache subnet group"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "Security group ID of the EKS cluster (for ingress rules)"
}

variable "create" {
  type        = bool
  description = "Whether to create the ElastiCache cluster (false = use in-cluster Redis)"
  default     = false
}

variable "node_type" {
  type        = string
  description = "ElastiCache node type"
  default     = "cache.t3.micro"
}

variable "redis_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.1"
}
