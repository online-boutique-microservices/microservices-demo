# 05 — Chi Tiết Environments

> **Ngày tạo:** 2026-09-30  
> **Phiên bản:** 1.0

---

## 5.1 So Sánh 3 Environments

| Thuộc tính | Dev | Staging | Production |
|:-----------|:----|:--------|:-----------|
| **Namespace** | `dev` | `staging` | `production` |
| **Mục đích** | Phát triển, test nhanh | QA, integration test | Phục vụ end-users |
| **EKS Node Type** | t3.medium (SPOT) | t3.medium (ON_DEMAND) | t3.large (ON_DEMAND) |
| **Node Count** | 2-4 | 2-4 | 3-8 |
| **Redis** | In-cluster (emptyDir) | In-cluster (emptyDir) | ElastiCache (managed, backup) |
| **Replicas (frontend)** | 1 | 2 | 3 + HPA (max 10) |
| **Replicas (checkout)** | 1 | 1 | 2 + HPA (max 6) |
| **LoadGenerator** | ✅ Có | ✅ Có | ❌ Không |
| **HPA** | ❌ | ❌ | ✅ (CPU 70%) |
| **ArgoCD Sync** | Auto | Auto | Manual |
| **CI Branch** | `develop` push | `main` push | `promote.sh staging prod` |
| **Resource Requests** | CPU: 50m, RAM: 32Mi | Mặc định | Mặc định |
| **Resource Limits** | CPU: 100m, RAM: 64Mi | Mặc định | Mặc định |
| **Chi phí ước tính** | ~$140/tháng | ~$140/tháng | ~$335/tháng |

## 5.2 Network Configuration

### Service Discovery (trong mỗi namespace)

| Service | DNS Name | Port | Protocol |
|:--------|:---------|:-----|:---------|
| frontend | `frontend.<ns>.svc.cluster.local` | 80 → 8080 | HTTP |
| frontend-external | `frontend-external.<ns>.svc.cluster.local` | 80 → 8080 | HTTP (LoadBalancer) |
| cartservice | `cartservice.<ns>.svc.cluster.local` | 7070 | gRPC |
| checkoutservice | `checkoutservice.<ns>.svc.cluster.local` | 5050 | gRPC |
| productcatalogservice | `productcatalogservice.<ns>.svc.cluster.local` | 3550 | gRPC |
| currencyservice | `currencyservice.<ns>.svc.cluster.local` | 7000 | gRPC |
| paymentservice | `paymentservice.<ns>.svc.cluster.local` | 50051 | gRPC |
| shippingservice | `shippingservice.<ns>.svc.cluster.local` | 50051 | gRPC |
| emailservice | `emailservice.<ns>.svc.cluster.local` | 5000 | gRPC |
| recommendationservice | `recommendationservice.<ns>.svc.cluster.local` | 8080 | gRPC |
| adservice | `adservice.<ns>.svc.cluster.local` | 9555 | gRPC |
| redis-cart | `redis-cart.<ns>.svc.cluster.local` | 6379 | TCP |

### External Access

| Environment | Method | Endpoint |
|:------------|:-------|:---------|
| Dev | `kubectl port-forward svc/frontend 8080:80 -n dev` | `localhost:8080` |
| Staging | LoadBalancer Service | `<ELB_DNS>:80` |
| Production | LoadBalancer + ALB Ingress | Custom domain (optional) |

## 5.3 Environment Variables

Các env vars quan trọng được cấu hình trong K8s manifests:

### Frontend Service
| Variable | Giá trị | Ghi chú |
|:---------|:--------|:--------|
| `PORT` | 8080 | HTTP server port |
| `PRODUCT_CATALOG_SERVICE_ADDR` | productcatalogservice:3550 | gRPC |
| `CURRENCY_SERVICE_ADDR` | currencyservice:7000 | gRPC |
| `CART_SERVICE_ADDR` | cartservice:7070 | gRPC |
| `RECOMMENDATION_SERVICE_ADDR` | recommendationservice:8080 | gRPC |
| `SHIPPING_SERVICE_ADDR` | shippingservice:50051 | gRPC |
| `CHECKOUT_SERVICE_ADDR` | checkoutservice:5050 | gRPC |
| `AD_SERVICE_ADDR` | adservice:9555 | gRPC |
| `ENABLE_PROFILER` | 0 | Cloud Profiler (GCP only) |

### CartService
| Variable | Dev/Staging | Production |
|:---------|:------------|:-----------|
| `REDIS_ADDR` | `redis-cart:6379` | `<ElastiCache_endpoint>:6379` |

## 5.4 Health Checks

Tất cả services đều có liveness + readiness probes:

| Service | Probe Type | Path/Port |
|:--------|:-----------|:----------|
| frontend | HTTP | `GET /_healthz` on port 8080 |
| checkoutservice | gRPC Health | port 5050 |
| cartservice | gRPC Health | port 7070 |
| productcatalogservice | gRPC Health | port 3550 |
| currencyservice | gRPC Health | port 7000 |
| paymentservice | gRPC Health | port 50051 |
| shippingservice | gRPC Health | port 50051 |
| emailservice | gRPC Health | port 5000 |
| recommendationservice | gRPC Health | port 8080 |
| adservice | gRPC Health | port 9555 |
| redis-cart | TCP Socket | port 6379 |
