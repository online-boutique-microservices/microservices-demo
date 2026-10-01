# 06 — Bảo Mật & DevSecOps

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0

---

## 6.1 Security Layers Đã Triển Khai

```
Layer 1: CI Pipeline Security
    ├── Trivy filesystem scan (source code dependencies)
    ├── Trivy image scan (Docker image vulnerabilities)
    └── ECR scan-on-push (AWS native scanning)

Layer 2: Authentication & Authorization
    ├── AWS OIDC Federation (keyless CI auth — no Access Keys)
    ├── IAM least-privilege policies (ECR push + EKS describe only)
    └── GitHub PAT scoped to config repo write

Layer 3: Container Security
    ├── runAsNonRoot: true
    ├── readOnlyRootFilesystem: true
    ├── allowPrivilegeEscalation: false
    ├── capabilities: drop ALL
    └── Per-service ServiceAccounts

Layer 4: Infrastructure Security
    ├── Private subnets for EKS nodes
    ├── Security groups (ElastiCache ← EKS only)
    ├── ECR immutable tags (prevent image overwrite)
    ├── S3 state bucket: encryption + block public access
    └── EKS audit logging enabled

Layer 5: GitOps Security
    ├── Config repo separated from app repo
    ├── Production manual sync (approval gate)
    └── Git audit trail for all deployments
```

## 6.2 CI Security Scanning

### Trivy Filesystem Scan
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Stage** | Stage 3 (song song với Unit Tests) |
| **Target** | `./src` (toàn bộ source code) |
| **Severity** | CRITICAL, HIGH (ignore-unfixed: true) |
| **Action khi phát hiện** | **Cảnh báo & Audit** (exit-code: 0, hiển thị bảng tóm tắt và đẩy SARIF lên Security tab, không block pipeline) |
| **Output** | Table summary trên console + SARIF report |

**Quét các file:**
- Go: `go.sum`
- Node.js: `package-lock.json`
- Python: `requirements.txt`
- C#: `*.csproj`
- Java: `build.gradle`

### Trivy Image Scan
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Stage** | Stage 4 (sau khi push image) |
| **Target** | Docker image vừa build |
| **Severity** | CRITICAL, HIGH |
| **Action khi phát hiện** | **Cảnh báo** (exit-code: 0, không block) |
| **Output** | Table format trong CI logs |

### ECR Scan-on-Push
| Thuộc tính | Giá trị |
|:-----------|:--------|
| **Trigger** | Tự động khi image được push lên ECR |
| **Scanner** | Amazon Inspector (AWS native) |
| **Results** | Xem trong AWS Console → ECR → Images |

## 6.3 Authentication — OIDC Federation

**Tại sao OIDC thay vì Access Keys:**
| Tiêu chí | Access Keys ❌ | OIDC Federation ✅ |
|:---------|:--------------|:-------------------|
| Credentials | Long-lived (phải rotate) | Short-lived (15 phút) |
| Lưu trữ | GitHub Secrets (risk) | Không lưu trữ |
| Scope | Khó giới hạn | Chỉ repo cụ thể |
| Audit | Khó trace | CloudTrail trace được |

**OIDC Flow:**
```
GitHub Actions → Request token từ GitHub OIDC Provider
    → Gửi token cho AWS STS (AssumeRoleWithWebIdentity)
    → AWS verify token + check conditions (repo match)
    → Trả về temporary credentials (15 min)
    → CI sử dụng credentials để push ECR
```

**IAM Policy Conditions:**
```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
    }
  }
}
```

## 6.4 Container Security (đã có sẵn trong manifests gốc)

Tất cả 11 service containers đều áp dụng:

```yaml
securityContext:
  fsGroup: 1000
  runAsGroup: 1000
  runAsNonRoot: true        # Không chạy dưới quyền root
  runAsUser: 1000

containers:
  - securityContext:
      allowPrivilegeEscalation: false   # Không cho escalate
      capabilities:
        drop:
          - ALL                          # Xóa toàn bộ Linux capabilities
      privileged: false                  # Không chạy privileged mode
      readOnlyRootFilesystem: true       # Filesystem chỉ đọc
```

## 6.5 ECR Image Security

| Setting | Giá trị | Lý do |
|:--------|:--------|:------|
| `image_tag_mutability` | IMMUTABLE | Không ai có thể overwrite image tag đã push |
| `scan_on_push` | true | Tự động scan CVE mỗi khi push |
| `encryption_type` | AES256 | Mã hóa images at rest |
| Lifecycle: untagged | Xóa sau 7 ngày | Dọn dẹp dangling images |
| Lifecycle: tagged | Giữ 25 gần nhất | Giới hạn storage cost |

## 6.6 Infrastructure Security

### VPC & Network
- **EKS nodes** chạy trong **private subnets** (không có public IP)
- **NAT Gateway** cho outbound traffic (pull images, etc.)
- **ElastiCache security group** chỉ cho phép port 6379 từ EKS cluster SG

### Terraform State
- S3 bucket: **versioning enabled** + **AES256 encryption** + **block all public access**
- DynamoDB: **state locking** (tránh concurrent apply)

### EKS
- **Audit logging** enabled (api, audit, authenticator)
- **OIDC provider** cho IRSA (IAM Roles for Service Accounts)
- **Public + Private endpoint** (Public cho CI access, Private cho internal)

## 6.7 Deployment Security

| Control | Cách triển khai |
|:--------|:---------------|
| **No direct kubectl** | CI không bao giờ chạy `kubectl apply` — chỉ ArgoCD sync |
| **Prod manual gate** | Production ArgoCD Application không auto-sync |
| **Git audit trail** | Mọi deploy đều có Git commit — truy vết ai, khi nào, cái gì |
| **ArgoCD self-heal** | Nếu ai sửa trực tiếp trên cluster, ArgoCD revert về Git state |
| **Prune enabled** | Resources bị xóa khỏi Git sẽ bị xóa khỏi cluster |

## 6.8 Khuyến Nghị Bổ Sung (chưa triển khai)

| Hạng mục | Công cụ gợi ý | Ưu tiên |
|:---------|:-------------|:--------|
| Secret Management | HashiCorp Vault / AWS Secrets Manager | 🔴 Cao |
| Policy Engine | OPA Gatekeeper | 🟡 Trung bình |
| Runtime Security | Falco | 🟡 Trung bình |
| RBAC | K8s Role/ClusterRole | 🔴 Cao |
| mTLS | Istio PeerAuthentication | 🟡 Trung bình |
| Image Signing | Cosign + Sigstore | 🟢 Thấp |
| SBOM | Syft | 🟢 Thấp |
| TLS Certificates | cert-manager + Let's Encrypt | 🔴 Cao |
