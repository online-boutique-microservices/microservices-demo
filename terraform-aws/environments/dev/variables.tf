variable "project_name" {
  type    = string
  default = "online-boutique"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_name" {
  type    = string
  default = "online-boutique-dev"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT — use SPOT for dev to save costs"
  default     = "SPOT"
}

variable "desired_nodes" {
  type    = number
  default = 3
}

variable "min_nodes" {
  type    = number
  default = 2
}

variable "max_nodes" {
  type    = number
  default = 4
}

variable "create_elasticache" {
  type        = bool
  description = "Use ElastiCache instead of in-cluster Redis"
  default     = false  # Dev uses in-cluster Redis to save costs
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or username"
}

variable "github_app_repo" {
  type        = string
  description = "GitHub app repo name"
  default     = "online-boutique-app"
}
