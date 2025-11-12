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

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}


data "azurerm_container_registry" "acr" {
  name                = "myprivateregistry15"
  resource_group_name = "aks-resources"
}


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
