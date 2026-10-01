# 07 — Runbook: Hướng Dẫn Vận Hành

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0

---

## 7.1 Triển Khai Lần Đầu (First-time Setup)

### Bước 1: Tạo Terraform State Backend
```bash
cd terraform-aws/global/state-backend
terraform init
terraform apply -auto-approve
```

### Bước 2: Deploy Dev Infrastructure
```bash
cd terraform-aws/environments/dev

# Sửa terraform.tfvars — set github_org
vim terraform.tfvars

terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

### Bước 3: Kết nối kubectl
```bash
# Lấy command từ terraform output
aws eks update-kubeconfig --name online-boutique-dev --region ap-southeast-1

# Verify
kubectl get nodes
kubectl get namespaces
```

### Bước 4: Cài ArgoCD
```bash
# Tạo namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Lấy admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward để truy cập UI
kubectl port-forward svc/argocd-server -n argocd 8443:443
# → Truy cập https://localhost:8443 (user: admin)
```

### Bước 5: Setup Config Repo
```bash
# Copy base manifests từ app repo
cp microservices-demo/kubernetes-manifests/*.yaml online-boutique-config/base/

# Thay thế ACCOUNT_ID trong kustomization.yaml
cd online-boutique-config
find . -name "kustomization.yaml" -exec sed -i 's/ACCOUNT_ID/<your-aws-account-id>/g' {} \;

# Push lên GitHub
git init && git add -A && git commit -m "init: config repo"
git remote add origin https://github.com/online-boutique-microservices/online-boutique-config.git
git push -u origin main
```

### Bước 6: Deploy ArgoCD Applications
```bash
# Sửa YOUR_ORG trong ArgoCD manifests
cd online-boutique-config
find argocd/ -name "*.yaml" -exec sed -i 's/online-boutique-microservices/<your-github-org>/g' {} \;
git add -A && git commit -m "fix: set org name" && git push

# Apply ArgoCD configs
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applications/
```

### Bước 7: Setup GitHub Secrets
```
GitHub → App Repo → Settings → Secrets → Actions:
  AWS_ACCOUNT_ID   = <12-digit AWS account ID>
  AWS_ROLE_ARN     = <terraform output github_actions_role_arn>
  CONFIG_REPO_PAT  = <GitHub PAT with repo scope>
```

---

## 7.2 Quy Trình Thường Ngày

### Deploy Code Mới Lên Dev
```bash
# Developer workflow
git checkout develop
git pull origin develop
git checkout -b feature/my-feature

# ... code changes ...

git add . && git commit -m "feat: my feature"
git push origin feature/my-feature

# Tạo PR → develop → Merge
# CI tự chạy → Image push → Dev auto-deploy
```

### Promote Dev → Staging
```bash
cd online-boutique-config
./scripts/promote.sh dev staging
# ArgoCD auto-sync staging
```

### Promote Staging → Production
```bash
cd online-boutique-config
./scripts/promote.sh staging prod

# ⚠️ Production: Manual sync required
# 1. Mở ArgoCD UI (https://argocd.example.com)
# 2. Tìm app "online-boutique-prod"
# 3. Click "Sync" → Review diff → Confirm
```

### Rollback Production
```bash
# Option 1: Revert commit trong config repo
cd online-boutique-config
git log --oneline envs/prod/    # Tìm commit trước đó
git revert <commit-sha>
git push
# → ArgoCD sẽ sync về version trước

# Option 2: Promote lại version staging cũ
# Trong ArgoCD UI → History → chọn revision cũ → Sync
```

---

## 7.3 Xử Lý Sự Cố

### CI Pipeline Failed

| Lỗi | Nguyên nhân | Cách xử lý |
|:-----|:-----------|:-----------|
| `Trivy found vulnerabilities` (exit 1) | CRITICAL/HIGH CVE trong dependencies | Update dependency → push lại |
| `docker build failed` | Dockerfile lỗi hoặc dependency issue | Check build logs, fix Dockerfile |
| `ECR login failed` | OIDC token expired hoặc IAM role sai | Check `AWS_ROLE_ARN` secret |
| `Config repo push failed` | PAT expired hoặc không đủ quyền | Regenerate `CONFIG_REPO_PAT` |
| `kustomize edit failed` | Image name không match | Check base kustomization.yaml |

### ArgoCD Sync Failed

```bash
# Kiểm tra status
kubectl get application -n argocd
kubectl describe application online-boutique-dev -n argocd

# Xem sync logs
argocd app get online-boutique-dev
argocd app sync online-boutique-dev --retry-limit 3

# Force sync (cẩn thận!)
argocd app sync online-boutique-dev --force --prune
```

| Lỗi | Nguyên nhân | Cách xử lý |
|:-----|:-----------|:-----------|
| `ComparisonError` | Manifest YAML sai | `kustomize build envs/dev/` để test local |
| `ImagePullBackOff` | Image không tồn tại trong ECR | Kiểm tra ECR repo, check image tag |
| `CrashLoopBackOff` | App crash khi start | `kubectl logs <pod> -n dev` |
| `OutOfSync` bị stuck | ArgoCD cache cũ | Refresh: ArgoCD UI → Hard Refresh |
| `SyncFailed: prune` | Resource bị protect | Thêm annotation `argocd.argoproj.io/sync-options: Prune=false` |

### Pods Not Starting

```bash
# Kiểm tra pod status
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev

# Xem logs
kubectl logs <pod-name> -n dev
kubectl logs <pod-name> -n dev --previous  # logs trước khi crash

# Common fixes
kubectl rollout restart deployment/<service> -n dev
kubectl delete pod <pod-name> -n dev   # Force recreate
```

### Terraform Issues

```bash
# State lock stuck
terraform force-unlock <lock-id>

# Drift detection
terraform plan  # Xem diff

# Import existing resource
terraform import <resource_type>.<name> <resource_id>

# Destroy single resource
terraform destroy -target=<resource>
```

---

## 7.4 Bảo Trì Định Kỳ

| Tần suất | Task | Lệnh/Hướng dẫn |
|:---------|:-----|:----------------|
| **Hàng tuần** | Review ECR vulnerability scan results | AWS Console → ECR → Images |
| **Hàng tuần** | Check ArgoCD sync status | ArgoCD UI → All Applications |
| **Hàng tháng** | Update Terraform providers | `terraform init -upgrade` |
| **Hàng tháng** | Review AWS cost | AWS Cost Explorer |
| **Hàng quý** | Rotate GitHub PAT | GitHub Settings → Tokens |
| **Hàng quý** | Update EKS version | Terraform `kubernetes_version` var |
| **Khi cần** | Cleanup ECR images | Tự động qua lifecycle policy |

---

## 7.5 Liên Hệ & Escalation

| Level | Phạm vi | Hành động |
|:------|:--------|:----------|
| L1 | CI failed, pod restart | Dev tự xử lý, check logs |
| L2 | ArgoCD sync failed, infra issue | DevOps team |
| L3 | EKS cluster down, data loss | Senior DevOps + AWS Support |
