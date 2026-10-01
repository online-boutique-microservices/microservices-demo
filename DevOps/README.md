# 📘 DevOps Documentation — Online Boutique

Thư mục này chứa toàn bộ tài liệu kỹ thuật về hệ thống DevOps đã được triển khai
cho project Online Boutique, phục vụ mục đích **audit, bàn giao, và tham khảo**.

## 📂 Cấu Trúc Tài Liệu

```
DevOps/
├── README.md                          ← (file này)
├── 01-architecture-overview.md        ← Tổng quan kiến trúc hệ thống
├── 02-infrastructure-aws.md           ← Chi tiết hạ tầng AWS (Terraform)
├── 03-ci-pipeline.md                  ← CI pipeline (GitHub Actions)
├── 04-cd-gitops.md                    ← CD pipeline (ArgoCD + GitOps)
├── 05-environments.md                 ← Chi tiết 3 environments
├── 06-security.md                     ← Bảo mật & DevSecOps
└── 07-runbook.md                      ← Hướng dẫn vận hành & xử lý sự cố
```

## 🔗 Liên Kết Repositories

| Repository | Đường dẫn | Mục đích |
|:-----------|:----------|:---------|
| **App Repo** | `microservices-demo/` | Source code 11 microservices + CI workflows + Terraform |
| **Config Repo** | `online-boutique-config/` | K8s manifests + ArgoCD apps (GitOps) |

## 📅 Lịch Sử Cập Nhật

| Ngày | Phiên bản | Nội dung |
|:-----|:----------|:---------|
| 2026-09-30 | v1.0 | Khởi tạo toàn bộ tài liệu DevOps |
