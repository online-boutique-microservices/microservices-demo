# ============================================================
# Dev Environment — Main Configuration
# Assembles all modules for the development environment.
# ============================================================

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # ⚠️ Thay <ACCOUNT_ID> bằng AWS Account ID thật (12 chữ số)
    # Lấy từ output của: cd global/state-backend && terraform output state_bucket_name
    bucket         = "online-boutique-tfstate-798836978890"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "online-boutique-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ─── VPC ─────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
}

# ─── EKS ─────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  environment        = var.environment
  kubernetes_version = var.kubernetes_version
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  capacity_type      = var.capacity_type
  desired_nodes      = var.desired_nodes
  min_nodes          = var.min_nodes
  max_nodes          = var.max_nodes
}

# ─── ECR (shared across environments, only create in dev) ─

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  force_delete = true # Allow cleanup in dev
}

# ─── ElastiCache Redis ───────────────────────────────────

module "elasticache" {
  source = "../../modules/elasticache"

  project_name                  = var.project_name
  environment                   = var.environment
  vpc_id                        = module.vpc.vpc_id
  private_subnet_ids            = module.vpc.private_subnet_ids
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  create                        = var.create_elasticache
  node_type                     = var.redis_node_type
}

# ─── GitHub Actions OIDC ─────────────────────────────────

module "github_oidc" {
  source = "../../modules/github-oidc"

  project_name = var.project_name
  region       = var.region
  github_org   = var.github_org
  github_repo  = var.github_app_repo
}
