# ============================================================
# GitHub Actions OIDC Module
# Creates IAM role that GitHub Actions can assume using OIDC
# federation — no long-lived credentials needed.
# ============================================================

# ─── OIDC Identity Provider for GitHub ───────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "terraform"
  }
}

# ─── IAM Role for GitHub Actions ─────────────────────────

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Only allow the specific repository to assume this role (supports classic, new 2026 immutable ID, and wildcards)
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:*",
            "repo:${var.github_org}@*/${var.github_repo}@*:*",
            "repo:${var.github_org}*${var.github_repo}*:*",
            "*${var.github_repo}:*"
          ]
        }
      }
    }]
  })

  tags = {
    Name      = "${var.project_name}-github-actions-role"
    ManagedBy = "terraform"
  }
}

# ─── ECR Push Policy ─────────────────────────────────────

resource "aws_iam_role_policy" "ecr_push" {
  name = "ecr-push-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}/*"
      }
    ]
  })
}

# ─── EKS Describe Policy (for kubeconfig) ────────────────

resource "aws_iam_role_policy" "eks_describe" {
  name = "eks-describe-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
      ]
      Resource = "*"
    }]
  })
}

data "aws_caller_identity" "current" {}
