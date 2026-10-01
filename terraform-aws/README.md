# Online Boutique — AWS Terraform Infrastructure
# ═══════════════════════════════════════════════

This directory contains Terraform configurations to deploy the Online Boutique
infrastructure on **AWS** (replacing the original GCP setup).

## Architecture

```
terraform-aws/
├── global/
│   └── state-backend/     # S3 + DynamoDB for Terraform state (run first)
├── modules/
│   ├── vpc/               # VPC, subnets, NAT, route tables
│   ├── eks/               # EKS cluster + managed node groups + OIDC
│   ├── ecr/               # 11 ECR repos with lifecycle policies
│   ├── elasticache/       # Redis cluster (optional per environment)
│   └── github-oidc/       # IAM role for GitHub Actions (keyless auth)
└── environments/
    ├── dev/               # Dev: SPOT instances, in-cluster Redis
    └── prod/              # Prod: ON_DEMAND, ElastiCache, larger nodes
```

## Quick Start

### Step 1: Create State Backend
```bash
cd global/state-backend
terraform init
terraform apply
```

### Step 2: Deploy Dev Environment
```bash
cd environments/dev

# Edit terraform.tfvars — set your github_org
terraform init
terraform plan
terraform apply
```

### Step 3: Configure kubectl
```bash
# Output from terraform apply:
aws eks update-kubeconfig --name online-boutique-dev --region ap-southeast-1
kubectl get nodes
```

### Step 4: Set GitHub Secrets
After `terraform apply`, set these GitHub repository secrets:
- `AWS_ACCOUNT_ID` — Your AWS account ID
- `AWS_ROLE_ARN` — Output `github_actions_role_arn` from terraform
- `CONFIG_REPO_PAT` — GitHub PAT with write access to config repo

## Cost Estimates

| Environment | Config | Monthly Estimate |
|:---|:---|:---|
| Dev | 3x t3.medium SPOT + no ElastiCache | ~$50-70/mo |
| Prod | 3x t3.large ON_DEMAND + ElastiCache | ~$200-250/mo |

> **Tip**: Run `terraform destroy` when not demoing to save costs.
