# ============================================================
# ECR Module
# Creates ECR repositories for all 11 microservices with
# lifecycle policies and vulnerability scanning.
# ============================================================

locals {
  services = toset([
    "frontend",
    "cartservice",
    "checkoutservice",
    "productcatalogservice",
    "currencyservice",
    "paymentservice",
    "shippingservice",
    "emailservice",
    "recommendationservice",
    "adservice",
    "loadgenerator",
  ])
}

resource "aws_ecr_repository" "services" {
  for_each = local.services

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = var.force_delete

  tags = {
    Name        = "${var.project_name}/${each.key}"
    Service     = each.key
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Lifecycle policy: cleanup old images to save storage costs
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last 25 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["sha-"]
          countType   = "imageCountMoreThan"
          countNumber = 25
        }
        action = { type = "expire" }
      }
    ]
  })
}
