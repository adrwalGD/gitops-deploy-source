terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
  }
}

# 1. Read the state from your infrastructure deployment
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "adrwal-terraform-state"  # Must match the backend config
    storage_account_name = "adrwalterraformstate"    # Must match the backend config
    container_name       = "tfstate"                 # Must match the backend config
    key                  = "infra.terraform.tfstate" # Must match the key
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.kube_config.0.host
    client_certificate     = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.client_certificate)
    client_key             = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.cluster_ca_certificate)
  }
}

# 2. Configure the Kubernetes provider using the output from the remote state
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.kube_config.0.host
  client_certificate     = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# 3. Create the Kubernetes secret for pulling images from your ACR
resource "kubernetes_secret" "acr_secret" {
  metadata {
    name      = "acr-secret"
    namespace = "default"
  }

  # Create the .dockerconfigjson content required by Kubernetes
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (data.terraform_remote_state.infra.outputs.acr_login_server) = {
          username = data.terraform_remote_state.infra.outputs.acr_admin_username
          password = data.terraform_remote_state.infra.outputs.acr_admin_password
          email    = "user@example.com"
          auth     = base64encode("${data.terraform_remote_state.infra.outputs.acr_admin_username}:${data.terraform_remote_state.infra.outputs.acr_admin_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "helm_release" "argocd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.51.2"

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.acr_secret
  ]

  # Example of customizing values.
  # For a full list, check the official argo-cd helm chart documentation.
  values = [
    <<-EOT
    server:
      service:
        type: LoadBalancer
    controller:
      metrics:
        enabled: true
    redis:
      metrics:
        enabled: true
    repoServer:
      metrics:
        enabled: true
    EOT
  ]
}

resource "kubernetes_manifest" "argo-app" {
  manifest = yamldecode(file("${path.module}/../argo-app.yaml"))

  depends_on = [helm_release.argocd]
}
