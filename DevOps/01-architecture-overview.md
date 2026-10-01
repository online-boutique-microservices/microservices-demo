# 01 — Tổng Quan Kiến Trúc Hệ Thống

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0  
> **Tác giả:** DevOps Team

---

## 1.1 Kiến Trúc Tổng Quan

Online Boutique là ứng dụng ecommerce microservices gồm **11 services** viết bằng
5 ngôn ngữ, giao tiếp qua gRPC. Hệ thống DevOps được thiết kế theo mô hình
**GitOps** với phân tách rõ ràng giữa CI (Continuous Integration) và CD (Continuous Delivery).

### Sơ Đồ Kiến Trúc End-to-End

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKFLOW                          │
│  ┌──────────┐    push     ┌──────────────┐                         │
│  │ Developer │───────────►│  App Repo    │                         │
│  └──────────┘             │  (GitHub)    │                         │
│                           └──────┬───────┘                         │
└──────────────────────────────────┼─────────────────────────────────┘
                                   │ trigger
┌──────────────────────────────────┼─────────────────────────────────┐
│                     CI PIPELINE (GitHub Actions)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  Lint &  │─►│ Security │─►│ Build &  │─►│ Update GitOps     │  │
│  │  Test    │  │ Scan     │  │ Push ECR │  │ Config Repo       │  │
│  └──────────┘  └──────────┘  └──────────┘  └─────────┬─────────┘  │
└──────────────────────────────────────────────────────┼─────────────┘
                                                       │ commit
┌──────────────────────────────────────────────────────┼─────────────┐
│                    CD PIPELINE (ArgoCD GitOps)                      │
│  ┌───────────────┐     watch      ┌──────────────┐                 │
│  │  Config Repo  │◄──────────────│   ArgoCD     │                 │
│  │  (GitHub)     │────────────────►│   Server     │                 │
│  └───────────────┘     sync       └──────┬───────┘                 │
│                                          │ deploy                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Dev (auto)  │  │ Staging(auto)│  │ Prod (manual)│             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼─────────────────────────────────┐
│                    AWS INFRASTRUCTURE (Terraform)                   │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌────────────┐  ┌───────────────┐ │
│  │ VPC  │  │ EKS  │  │ ECR  │  │ ElastiCache│  │ GitHub OIDC   │ │
│  │3 AZs │  │Cluster│  │11 Repos│ │ Redis     │  │ (keyless)     │ │
│  └──────┘  └──────┘  └──────┘  └────────────┘  └───────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

## 1.2 Repository Strategy

| Repository | Loại | Nội dung |
|:-----------|:-----|:---------|
| **`microservices-demo`** (App Repo) | Source code | 11 service source code, Dockerfiles, CI workflows, Terraform IaC |
| **`online-boutique-config`** (Config Repo) | GitOps manifests | Kustomize base + overlays, ArgoCD Applications, promote script |

**Lý do tách 2 repos:**
- **Separation of concerns**: Developer chỉ đụng app repo, CI tự cập nhật config repo
- **Security**: Giới hạn write access vào config repo (chỉ CI bot + senior DevOps)
- **Audit trail**: Mọi thay đổi triển khai đều truy vết được qua Git history của config repo
- **Tránh vòng lặp CI**: Push vào config repo không trigger CI pipeline của app repo

## 1.3 Branching Strategy

### App Repo
```
main            ← Production-ready, tagged releases
├── develop     ← Integration branch (CI → deploy to dev)
├── feature/*   ← Feature branches (PR → develop)
├── hotfix/*    ← Emergency fixes (PR → main)
└── release/*   ← Release candidates
```

| Branch | CI Trigger | Deploy Target |
|:-------|:-----------|:-------------|
| `feature/*` → PR to `develop` | Tests + scan only (no build) | — |
| `develop` (push) | Full CI → build → push ECR → update dev | Dev environment |
| `main` (push) | Full CI → build → push ECR → update staging | Staging environment |
| Production | — | Manual promote staging → prod |

### Config Repo
```
main (single branch) — ArgoCD watches this branch
├── envs/dev/          ← Auto-updated by CI
├── envs/staging/      ← Auto-updated by CI (main branch push)
└── envs/prod/         ← Updated by promote.sh (manual)
```

## 1.4 Công Nghệ Sử Dụng

| Layer | Công nghệ | Phiên bản | Mục đích |
|:------|:----------|:----------|:---------|
| **IaC** | Terraform | >= 1.7 | Provision AWS infrastructure |
| **Cloud** | AWS | — | EKS, ECR, ElastiCache, VPC, IAM |
| **Container Orchestration** | Kubernetes (EKS) | 1.31 | Chạy microservices |
| **Container Registry** | AWS ECR | — | Lưu trữ Docker images |
| **CI** | GitHub Actions | — | Build, test, scan, push |
| **CD** | ArgoCD | — | GitOps-based deployment |
| **Manifest Management** | Kustomize | — | Environment overlays |
| **Security Scanning** | Trivy | latest | CVE scanning (source + image) |
| **Auth** | AWS OIDC | — | Keyless CI → AWS authentication |
| **Load Testing** | Locust | — | Traffic simulation |
