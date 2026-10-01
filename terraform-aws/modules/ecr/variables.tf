variable "project_name" {
  type        = string
  description = "Project name used for repository naming prefix"
}

variable "environment" {
  type        = string
  description = "Environment name for tagging"
}

variable "force_delete" {
  type        = bool
  description = "If true, ECR repos can be deleted even if they contain images"
  default     = false
}
