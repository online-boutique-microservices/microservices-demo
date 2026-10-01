# 02 — Hạ Tầng AWS (Terraform)

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0  
> **Đường dẫn code:** `terraform-aws/`

---

## 2.1 Tổng Quan Modules

Hạ tầng AWS được chia thành **5 Terraform modules** tái sử dụng, tổ hợp bởi
các environment configurations.

```
terraform-aws/
├── global/state-backend/     # Bootstrap: S3 + DynamoDB
├── modules/
│   ├── vpc/                  # Networking
│   ├── eks/                  # Kubernetes cluster
│   ├── ecr/                  # Container registry
│   ├── elasticache/          # Managed Redis
│   └── github-oidc/          # CI authentication
└── environments/
    ├── dev/                  # Dev config (SPOT, no ElastiCache)
    └── prod/                 # Prod config (ON_DEMAND, ElastiCache)
```

## 2.2 Chi Tiết Từng Module

### Module: `vpc`
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **File** | `terraform-aws/modules/vpc/main.tf` |
| **CIDR** | `10.0.0.0/16` |
| **AZs** | 3 Availability Zones |
| **Public Subnets** | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` |
| **Private Subnets** | `10.0.10.0/24`, `10.0.20.0/24`, `10.0.30.0/24` |
| **NAT Gateway** | 1 (single, cost-optimized) |

**Resources tạo ra:**
- `aws_vpc` — VPC chính
- `aws_subnet` × 6 — 3 public + 3 private
- `aws_internet_gateway` — Cho public subnets
- `aws_nat_gateway` + `aws_eip` — Cho private subnets ra internet
- `aws_route_table` × 2 + associations — Routing

**Subnet Tagging cho EKS:**
- Public: `kubernetes.io/role/elb = 1` (cho ALB)
- Private: `kubernetes.io/role/internal-elb = 1` (cho internal LB)

### Module: `eks`
| Thuộc tính | Dev | Prod |
|:-----------|:----|:-----|
| **File** | `terraform-aws/modules/eks/main.tf` |
| **K8s Version** | 1.31 | 1.31 |
| **Instance Type** | t3.medium | t3.large |
| **Capacity** | SPOT | ON_DEMAND |
| **Node Count** | 2-4 (desired: 3) | 3-8 (desired: 3) |
| **API Access** | Public + Private | Public + Private |
| **Logging** | api, audit, authenticator | api, audit, authenticator |

**Resources tạo ra:**
- `aws_eks_cluster` — EKS control plane
- `aws_eks_node_group` — Managed worker nodes
- `aws_iam_role` × 2 — Cluster role + Node role
- `aws_iam_role_policy_attachment` × 5 — Required IAM policies
- `aws_iam_openid_connect_provider` — OIDC cho IRSA (IAM Roles for Service Accounts)

**IAM Policies gắn cho Node Group:**
1. `AmazonEKSWorkerNodePolicy`
2. `AmazonEKS_CNI_Policy`
3. `AmazonEC2ContainerRegistryReadOnly`

### Module: `ecr`
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **File** | `terraform-aws/modules/ecr/main.tf` |
| **Số repos** | 11 (1 per service) |
| **Tag Mutability** | IMMUTABLE |
| **Scan on Push** | Enabled |
| **Encryption** | AES256 |

**11 Repositories:**
```
online-boutique/frontend
online-boutique/cartservice
online-boutique/checkoutservice
online-boutique/productcatalogservice
online-boutique/currencyservice
online-boutique/paymentservice
online-boutique/shippingservice
online-boutique/emailservice
online-boutique/recommendationservice
online-boutique/adservice
online-boutique/loadgenerator
```

**Lifecycle Policies:**
1. Xóa untagged images sau 7 ngày
2. Giữ tối đa 25 tagged images (prefix `sha-`)

### Module: `elasticache`
| Thuộc tính | Dev | Prod |
|:-----------|:----|:-----|
| **File** | `terraform-aws/modules/elasticache/main.tf` |
| **Enabled** | ❌ No (in-cluster Redis) | ✅ Yes |
| **Node Type** | — | cache.t3.small |
| **Engine** | — | Redis 7.1 |
| **Snapshot Retention** | — | 7 days |
| **Maintenance** | — | Sunday 03:00-04:00 UTC |

**Security:**
- Security group chỉ cho phép ingress port 6379 từ EKS cluster security group
- Deployed trong private subnets

### Module: `github-oidc`
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **File** | `terraform-aws/modules/github-oidc/main.tf` |
| **Provider** | `https://token.actions.githubusercontent.com` |
| **Auth Method** | OIDC Federation (không dùng Access Keys) |
| **Scope** | Chỉ repo cụ thể được assume role |

**IAM Permissions cho GitHub Actions:**
1. **ECR**: `GetAuthorizationToken`, `BatchCheckLayerAvailability`, `PutImage`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`
2. **EKS**: `DescribeCluster`, `ListClusters`

## 2.3 Terraform State Management

| Thành phần | Resource | Mục đích |
|:-----------|:---------|:---------|
| **S3 Bucket** | `online-boutique-terraform-state` | Lưu trữ state files |
| **DynamoDB Table** | `online-boutique-terraform-locks` | State locking (tránh race condition) |
| **Versioning** | Enabled | Rollback state nếu cần |
| **Encryption** | AES256 | Bảo mật state data |
| **Public Access** | Blocked | Tất cả public access bị chặn |

**State file paths:**
- Dev: `environments/dev/terraform.tfstate`
- Prod: `environments/prod/terraform.tfstate`

## 2.4 Ước Tính Chi Phí

| Resource | Dev (SPOT) | Prod (ON_DEMAND) |
|:---------|:-----------|:-----------------|
| EKS Control Plane | $73/tháng | $73/tháng |
| EC2 Nodes (3x t3.medium) | ~$30/tháng | ~$100/tháng |
| EC2 Nodes (3x t3.large) | — | ~$200/tháng |
| NAT Gateway | ~$35/tháng | ~$35/tháng |
| ElastiCache | $0 (skip) | ~$25/tháng |
| ECR Storage | ~$1/tháng | ~$1/tháng |
| **Tổng ước tính** | **~$140/tháng** | **~$335/tháng** |
