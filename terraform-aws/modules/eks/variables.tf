variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for EKS"
  default     = "1.31"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the EKS cluster"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
  default     = "t3.medium"
}

variable "capacity_type" {
  type        = string
  description = "Capacity type for the node group (ON_DEMAND or SPOT)"
  default     = "ON_DEMAND"
}

variable "desired_nodes" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 3
}

variable "min_nodes" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 2
}

variable "max_nodes" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 6
}

variable "cluster_public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to access the EKS API endpoint"
  default     = ["0.0.0.0/0"]
}
