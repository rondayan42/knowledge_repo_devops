# Knowledge Repository - DevOps

Kubernetes manifests for the Knowledge Repository application.

## Quick Start
```bash
# Create namespace
kubectl create namespace knowledge-repo

# Deploy all components
kubectl apply -f kubernetes/database/
kubectl apply -f kubernetes/backend/
kubectl apply -f kubernetes/frontend/
kubectl apply -f kubernetes/ingress/

# Seed root user
kubectl exec -it deployment/knowledge-repo-server -n knowledge-repo -- python seed_root_user.py
```

## Access

**Development (port-forward):**
```bash
kubectl port-forward svc/knowledge-repo-client 8080:80 -n knowledge-repo
kubectl port-forward svc/knowledge-repo-server 5000:5000 -n knowledge-repo
```
Open: http://localhost:8080

**Production (ingress):**
Open: http://api.knowledge-repo.local

## Default Login

- **Email:** rondayan42@gmail.com
- **Password:** BsmartRoot2025!