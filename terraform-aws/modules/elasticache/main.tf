# ============================================================
# ElastiCache Redis Module
# Creates an ElastiCache Redis cluster for cart data storage,
# replacing the in-cluster Redis or GCP Memorystore.
# ============================================================

# ─── Subnet Group ────────────────────────────────────────

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis-subnet"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─── Security Group ──────────────────────────────────────

resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  vpc_id      = var.vpc_id
  description = "Security group for ElastiCache Redis"

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── ElastiCache Redis Cluster ───────────────────────────

resource "aws_elasticache_cluster" "redis" {
  count = var.create ? 1 : 0

  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  engine_version       = var.redis_version
  node_type            = var.node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  # Maintenance window (UTC) — Sunday 3-4 AM
  maintenance_window = "sun:03:00-sun:04:00"

  # Snapshot for backup
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
