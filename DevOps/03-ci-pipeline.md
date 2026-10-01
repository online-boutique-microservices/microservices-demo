# 03 — CI Pipeline (GitHub Actions)

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0  
> **File cấu hình:** `.github/workflows/ci-pipeline.yaml`

---

## 3.1 Tổng Quan Pipeline

CI Pipeline được thiết kế với **5 stages** tuần tự, sử dụng GitHub Actions.
Pipeline chỉ trigger khi có thay đổi trong thư mục `src/`.

```
Trigger (push/PR)
    │
    ▼
┌─────────────────────┐
│ Stage 1: Detect     │  Xác định services nào bị thay đổi
│ Changed Services    │  → Tránh build lại toàn bộ 11 services
└─────────┬───────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌────────┐ ┌──────────────┐
│Stage 2:│ │ Stage 3:     │  Chạy song song
│ Test   │ │ Security Scan│
└────┬───┘ └──────┬───────┘
     └─────┬──────┘
           ▼
┌─────────────────────┐
│ Stage 4: Build &    │  Matrix strategy: mỗi service = 1 job
│ Push to ECR         │  + Trivy image scan sau khi push
└─────────┬───────────┘
          │ (chỉ khi push, không phải PR)
          ▼
┌─────────────────────┐
│ Stage 5: Update     │  Commit image tag mới vào Config Repo
│ GitOps Manifests    │  → ArgoCD tự phát hiện và deploy
└─────────────────────┘
```

## 3.2 Chi Tiết Từng Stage

### Stage 1: Detect Changed Services
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Job name** | `detect-changes` |
| **Runs on** | `ubuntu-latest` |
| **Output** | `services` (JSON array) |

**Logic:**
1. So sánh `git diff` giữa commit trước và hiện tại
2. Kiểm tra thay đổi trong `src/<service_name>/` cho mỗi service
3. Nếu không detect được (first push), build tất cả 11 services
4. Output JSON array cho matrix build: `["frontend", "cartservice", ...]`

**Lý do:** Tránh build 11 Docker images (~15-20 phút) khi chỉ sửa 1 service.

### Stage 2: Unit Tests
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Job name** | `test` |
| **Go version** | 1.27 |
| **.NET version** | 10.0 |
| **Coverage** | Enabled (`-coverprofile`) |
| **Race detector** | Enabled (`-race`) |

**Test suites:**
| Service | Ngôn ngữ | Lệnh |
|:--------|:---------|:------|
| `shippingservice` | Go | `go test -v -race ./...` |
| `productcatalogservice` | Go | `go test -v -race ./...` |
| `frontend/validator` | Go | `go test -v -race ./...` |
| `cartservice` | C# | `dotnet test` |

### Stage 3: Security Scan (Source Code)
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Job name** | `security-scan` |
| **Tool** | Trivy (aquasecurity/trivy-action) |
| **Scan type** | Filesystem (`fs`) |
| **Target** | `./src` |
| **Severity** | CRITICAL, HIGH (ignore-unfixed: true) |
| **Exit code** | 0 (Audit mode: cảnh báo ra console log + GitHub Security tab, không block pipeline) |
| **Output** | Table summary (console) + SARIF → GitHub Security tab |

**Quét:**
- Dependency vulnerabilities trong `go.sum`, `package-lock.json`, `requirements.txt`, `.csproj`
- Known CVEs trong các thư viện

### Stage 4: Build & Push to ECR
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Job name** | `build-push` |
| **Condition** | Chỉ chạy khi `push` (không chạy cho PR) |
| **Strategy** | Matrix (parallel build per service) |
| **fail-fast** | `false` (service khác vẫn build nếu 1 cái fail) |
| **Auth** | AWS OIDC (keyless) |
| **Builder** | Docker Buildx |
| **Cache** | GitHub Actions cache (`type=gha`) |

**Image tagging:**
```
ECR_REGISTRY/online-boutique/<service>:sha-<commit_sha>      ← Immutable
ECR_REGISTRY/online-boutique/<service>:<branch>-latest        ← Mutable (dev reference)
```

**Sau khi push:** Chạy Trivy Image Scan (CRITICAL/HIGH) — cảnh báo nhưng không block.

### Stage 5: Update GitOps Config Repo
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Job name** | `update-gitops` |
| **Condition** | Chỉ `develop` hoặc `main` branch |
| **Auth** | Personal Access Token (`CONFIG_REPO_PAT`) |
| **Tool** | `kustomize edit set image` |

**Environment mapping:**
| App Repo Branch | Target Environment | Config Repo Path |
|:----------------|:-------------------|:-----------------|
| `develop` | Dev | `envs/dev/kustomization.yaml` |
| `main` | Staging | `envs/staging/kustomization.yaml` |

**Commit message format:**
```
ci(dev): update images → sha-abc1234

Source: org/online-boutique-app@abc1234
Branch: develop
Services: ["frontend", "cartservice"]
```

## 3.3 Terraform CI Pipeline

| Thuộc tính | Giá trị |
|:-----------|:--------|
| **File** | `.github/workflows/terraform-ci.yaml` |
| **Trigger** | PR/push thay đổi `terraform-aws/` |
| **Environments** | Matrix: `[dev, prod]` |

**Checks:**
1. `terraform fmt -check -recursive` — Kiểm tra formatting
2. `terraform init -backend=false` — Validate syntax
3. `terraform validate` — Validate configuration

## 3.4 GitHub Secrets Cần Thiết

| Secret Name | Giá trị | Nguồn |
|:------------|:--------|:------|
| `AWS_ACCOUNT_ID` | AWS Account ID (12 chữ số) | AWS Console |
| `AWS_ROLE_ARN` | IAM Role ARN cho OIDC | `terraform output github_actions_role_arn` |
| `CONFIG_REPO_PAT` | GitHub PAT (write access config repo) | GitHub Settings → Tokens |

## 3.5 Concurrency Control

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```
- Mỗi branch chỉ chạy **1 CI pipeline tại một thời điểm**
- Push mới sẽ **cancel** pipeline đang chạy của cùng branch
- Tránh lãng phí resources và race conditions
