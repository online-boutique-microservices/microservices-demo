# 04 — CD Pipeline (ArgoCD + GitOps)

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0  
> **Config Repo:** `online-boutique-config/`

---

## 4.1 Nguyên Tắc GitOps

Hệ thống CD tuân thủ **4 nguyên tắc GitOps** của OpenGitOps:

| # | Nguyên tắc | Cách triển khai |
|:--|:-----------|:---------------|
| 1 | **Declarative** | Toàn bộ K8s manifests khai báo trong YAML (Kustomize) |
| 2 | **Versioned & Immutable** | Config repo trên Git — mọi thay đổi đều có commit history |
| 3 | **Pulled Automatically** | ArgoCD tự pull từ Git, không có `kubectl apply` từ CI |
| 4 | **Continuously Reconciled** | ArgoCD liên tục so sánh desired state vs live state |

## 4.2 Config Repo Structure

```
online-boutique-config/
├── base/                           # Shared manifests (11 services)
│   ├── kustomization.yaml
│   ├── frontend.yaml
│   ├── cartservice.yaml
│   ├── checkoutservice.yaml
│   ├── productcatalogservice.yaml
│   ├── currencyservice.yaml
│   ├── paymentservice.yaml
│   ├── shippingservice.yaml
│   ├── emailservice.yaml
│   ├── recommendationservice.yaml
│   ├── adservice.yaml
│   └── loadgenerator.yaml
│
├── envs/
│   ├── dev/                        # Dev overlay
│   │   ├── kustomization.yaml      #   Minimal resources, all 11 services
│   │   └── namespace.yaml
│   ├── staging/                    # Staging overlay
│   │   ├── kustomization.yaml      #   2 replicas frontend
│   │   └── namespace.yaml
│   └── prod/                       # Production overlay
│       ├── kustomization.yaml      #   3 replicas, ElastiCache, no loadgen
│       ├── namespace.yaml
│       └── hpa.yaml                #   HorizontalPodAutoscaler
│
├── argocd/
│   ├── projects/
│   │   └── online-boutique.yaml    # AppProject definition
│   └── applications/
│       ├── dev.yaml                # Auto-sync
│       ├── staging.yaml            # Auto-sync
│       └── prod.yaml               # Manual sync only
│
└── scripts/
    └── promote.sh                  # Environment promotion script
```

## 4.3 ArgoCD Applications

### AppProject: `online-boutique`

| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Source Repos** | Chỉ config repo |
| **Destinations** | Namespaces: `dev`, `staging`, `production` |
| **Cluster** | `https://kubernetes.default.svc` (in-cluster) |
| **Orphaned Resources** | Warn enabled |

### Application Configurations

| Application | Namespace | Sync Policy | Prune | Self-Heal | Retry |
|:------------|:----------|:------------|:------|:----------|:------|
| `online-boutique-dev` | `dev` | **Automated** ✅ | ✅ | ✅ | 3 lần |
| `online-boutique-staging` | `staging` | **Automated** ✅ | ✅ | ✅ | 3 lần |
| `online-boutique-prod` | `production` | **Manual** 🔒 | — | — | — |

**Giải thích sync policies:**
- **Automated + Prune**: ArgoCD tự động sync VÀ xóa resources không còn trong Git
- **Self-Heal**: Nếu ai đó `kubectl edit` trực tiếp, ArgoCD sẽ revert về Git state
- **Manual (prod)**: Bắt buộc review diff trong ArgoCD UI trước khi sync

## 4.4 Kustomize Overlay Strategy

### Base Layer
Chứa 11 service manifests gốc (copy từ `kubernetes-manifests/`). Mỗi manifest gồm:
- `Deployment` — Container spec, env vars, probes, security context
- `Service` (ClusterIP) — Internal service discovery
- `ServiceAccount` — Per-service identity

### Overlay Customizations

| Customization | Dev | Staging | Prod |
|:-------------|:----|:--------|:-----|
| **Namespace** | `dev` | `staging` | `production` |
| **Image registry** | ECR | ECR | ECR |
| **CPU requests** | 50m | (base) | (base) |
| **CPU limits** | 100m | (base) | (base) |
| **Memory requests** | 32Mi | (base) | (base) |
| **Memory limits** | 64Mi | (base) | (base) |
| **Frontend replicas** | 1 | 2 | 3 |
| **Checkout replicas** | 1 | 1 | 2 |
| **Redis** | In-cluster | In-cluster | ElastiCache |
| **LoadGenerator** | ✅ | ✅ | ❌ Removed |
| **HPA** | ❌ | ❌ | ✅ |

## 4.5 HPA (Production Only)

| Service | Min | Max | CPU Target |
|:--------|:----|:----|:-----------|
| `frontend` | 3 | 10 | 70% |
| `checkoutservice` | 2 | 6 | 70% |
| `currencyservice` | 2 | 8 | 70% |

`currencyservice` có max replicas cao nhất vì nó là **highest QPS service** (mọi
hiển thị giá đều gọi currency conversion).

## 4.6 Environment Promotion Flow

```
┌─────────┐  CI auto-update  ┌──────────┐  promote.sh  ┌──────────┐
│   Dev   │ ◄───────────── │ CI pushes │             │          │
│         │                 │ image tag │             │          │
│ (auto   │                 └──────────┘             │          │
│  sync)  │                                          │          │
└────┬────┘                                          │          │
     │ Test OK                                       │          │
     ▼                                               │          │
┌─────────┐  promote.sh dev staging                  │          │
│ Staging │ ◄──────────────────────────────          │          │
│         │                                          │          │
│ (auto   │                                          │          │
│  sync)  │                                          │          │
└────┬────┘                                          │          │
     │ QA OK                                         │          │
     ▼                                               │          │
┌─────────┐  promote.sh staging prod                 │          │
│  Prod   │ ◄──────────────────────────────          │          │
│         │                                          │          │
│ (manual │  ArgoCD UI → Review diff → Click Sync    │          │
│  sync)  │                                          │          │
└─────────┘                                          │          │
```

### Promote Script (`scripts/promote.sh`)

**Cách sử dụng:**
```bash
./scripts/promote.sh dev staging      # Dev → Staging
./scripts/promote.sh staging prod     # Staging → Production
```

**Logic:**
1. Đọc `newTag` từ source `kustomization.yaml`
2. Dùng `kustomize edit set image` cập nhật target `kustomization.yaml`
3. Commit + push → ArgoCD phát hiện và sync

## 4.7 Notifications

ArgoCD Applications được cấu hình annotations cho **ArgoCD Notifications**:

| Event | Channel (Slack) |
|:------|:---------------|
| `on-sync-succeeded` | `#devops-alerts` (dev/staging), `#devops-critical` (prod) |
| `on-sync-failed` | `#devops-alerts` (dev/staging), `#devops-critical` (prod) |
| `on-health-degraded` | `#devops-alerts` (dev), `#devops-critical` (prod) |
