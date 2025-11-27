# 1. Deploy Helm Charts with Terraform

## 📁 Terraform in a **separate folder**

Recommended project structure:

```bash
├── Terraform
│   ├── main.tf
│   ├── terraform.tfstate
│   └── terraform.tfstate.backup
```

This automates the full application deployment into AKS.

## 🚀 Deploy Using Terraform

```bash
terraform init
terraform apply -auto-approve
```

---

# 2. ArgoCD

## Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Expose ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Get Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Create ArgoCD App

```bash
argocd app create web --repo https://github.com/almazova09/web-project --path helm --dest-server https://kubernetes.default.svc --dest-namespace default
```

## Sync

```bash
argocd app sync web
```

---
