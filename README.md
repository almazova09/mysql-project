# 1. Deploy Helm Charts with Terraform

```
Terraform in **separate folder**:

```bash
├── Terraform
│   ├── main.tf
│   ├── terraform.tfstate
│   └── terraform.tfstate.backup
```

Below is an example of deploying **MySQL**, **API**, and **Web** Helm charts using Terraform. This automates the full application deployment into AKS.

```
## 1.1 Terraform Providers

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }
}

provider "azurerm" {
  features {}
  use_cli = true
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
```

---

## 1.2 Create Namespace

```hcl
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}
```

---

## 1.3 Pull ACR Credentials

```hcl
data "azurerm_container_registry" "acr" {
  name                = "myprivateregistry15"
  resource_group_name = "aks-resources"
}
```

---

## 1.4 Create ACR Docker Pull Secret

```hcl
resource "kubernetes_secret" "acr_auth" {
  metadata {
    name      = "acr-auth"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${data.azurerm_container_registry.acr.login_server}" = {
          username = data.azurerm_container_registry.acr.admin_username
          password = data.azurerm_container_registry.acr.admin_password
          auth     = base64encode("${data.azurerm_container_registry.acr.admin_username}:${data.azurerm_container_registry.acr.admin_password}")
        }
      }
    })
  }
}
```

---

## 1.5 Deploy MySQL Helm Chart

```hcl
resource "helm_release" "mysql" {
  name              = "mysql"
  namespace         = kubernetes_namespace.apps.metadata[0].name
  chart             = "../Helm/mysql"
  dependency_update = false
  depends_on        = [kubernetes_secret.acr_auth]

  set {
    name  = "auth.rootPassword"
    value = "rootpass123"
  }

  set {
    name  = "auth.user"
    value = "kaizen"
  }

  set {
    name  = "auth.password"
    value = "Hello123!"
  }

  set {
    name  = "auth.database"
    value = "hello"
  }
}
```

---

## 1.6 Deploy API Helm Chart

```hcl
resource "helm_release" "api" {
  name       = "api"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "../Helm/api"
  depends_on = [helm_release.mysql, kubernetes_secret.acr_auth]

  set {
    name  = "image.repository"
    value = "${data.azurerm_container_registry.acr.login_server}/api"
  }

  set {
    name  = "image.tag"
    value = "v1"
  }

  set {
    name  = "config.DBHOST"
    value = "mysql"
  }

  set {
    name  = "secret.DBUSER"
    value = "kaizen"
  }

  set {
    name  = "secret.DBPASS"
    value = "Hello123!"
  }
}
```

---

## 1.7 Deploy Web Helm Chart

```hcl
resource "helm_release" "web" {
  name       = "web"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "../Helm/web"
  depends_on = [helm_release.api, kubernetes_secret.acr_auth]

  set {
    name  = "image.repository"
    value = "${data.azurerm_container_registry.acr.login_server}/web"
  }

  set {
    name  = "image.tag"
    value = "v1"
  }

  set {
    name  = "config.API_HOST"
    value = "http://api.apps.svc.cluster.local:3001"
  }
}

Deploy:

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
