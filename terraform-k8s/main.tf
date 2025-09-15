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
    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = "1.19.0"
    # }
    # http = {
    #   source  = "hashicorp/http"
    #   version = "~> 3.0"
    # }
    # yaml = {
    #   source  = "hashicorp/yaml"
    #   version = "~> 2.2"
    # }
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
  # depends_on = [aws_eks_node_group.main]
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "4.5.2"

  namespace = "argocd"

  create_namespace = true

  # set {
  #   name  = "server.service.type"
  #   value = "LoadBalancer"
  # }

  # set {
  #   name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
  #   value = "nlb"
  # }
}




# data "http" "argocd_install" {
#   url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
# }

# data "kubectl_file_documents" "argocd_manifests" {
#   content = data.http.argocd_install.response_body
# }

# resource "kubernetes_manifest" "argocd" {
#   # The for_each meta-argument creates an instance for each YAML document found in the file.
#   for_each = data.kubectl_file_documents.argocd_manifests.manifests

#   # yamldecode() parses the YAML string from the loop into a Terraform object
#   # that the manifest attribute can understand.
#   manifest = yamldecode(each.value)

#   # Ensure the namespace is created before attempting to apply manifests.
#   depends_on = [kubernetes_namespace.argocd]
# }

# # 4. Example: Deploy a pod using an image from your ACR
# resource "kubernetes_manifest" "nginx_deployment" {
#   manifest = {
#     "apiVersion" = "apps/v1"
#     "kind"       = "Deployment"
#     "metadata" = {
#       "name"      = "nginx-deployment"
#       "namespace" = "default"
#     }
#     "spec" = {
#       "replicas" = 2
#       "selector" = {
#         "matchLabels" = {
#           "app" = "nginx"
#         }
#       }
#       "template" = {
#         "metadata" = {
#           "labels" = {
#             "app" = "nginx"
#           }
#         }
#         "spec" = {
#           # Reference the secret you created above
#           "imagePullSecrets" = [
#             {
#               "name" = kubernetes_secret.acr_secret.metadata[0].name
#             }
#           ]
#           "containers" = [
#             {
#               "image" = "${data.terraform_remote_state.infra.outputs.acr_login_server}/nginx:latest" # Assumes you pushed an nginx image to your ACR
#               "name"  = "nginx"
#               "ports" = [
#                 {
#                   "containerPort" = 80
#                 }
#               ]
#             }
#           ]
#         }
#       }
#     }
#   }

#   # Add a dependency to ensure the secret is created before the deployment
#   depends_on = [kubernetes_secret.acr_secret]
# }
