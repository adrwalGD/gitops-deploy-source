terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.44.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "adrwal-terraform-state"
    storage_account_name = "adrwalterraformstate"
    container_name       = "tfstate"
    key                  = "infra.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "afa1a461-3f97-478d-a062-c8db00c98741"
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}

locals {
  resource_name = "${var.resources_name_prefix}${random_string.suffix.result}"
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_name
  location = var.location
}

resource "azurerm_container_registry" "main" {
  name                          = local.resource_name
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "Standard"
  admin_enabled                 = true
  public_network_access_enabled = true
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.resource_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${local.resource_name}-dns"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                 = "agentpool"
    node_count           = 1
    vm_size              = "Standard_D2ps_v6"
    os_disk_size_gb      = 128
    os_disk_type         = "Managed"
    os_sku               = "Ubuntu"
    max_pods             = 110
    type                 = "VirtualMachineScaleSets"
    auto_scaling_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"

  }

  sku_tier                          = "Free"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true
}

# resource "kubernetes_namespace" "argocd" {
#   metadata {
#     name = "argocd"
#   }

#   depends_on = [azurerm_kubernetes_cluster.main]
# }

# resource "kubernetes_secret" "acr_secret" {
#   metadata {
#     name      = "acr-secret"
#     namespace = "default"
#   }

#   # Create the .dockerconfigjson content required by Kubernetes
#   data = {
#     ".dockerconfigjson" = jsonencode({
#       auths = {
#         (azurerm_container_registry.main.login_server) = {
#           username = azurerm_container_registry.main.admin_username
#           password = azurerm_container_registry.main.admin_password
#           email    = "user@example.com"
#           auth     = base64encode("${azurerm_container_registry.main.admin_username}:${azurerm_container_registry.main.admin_password}")
#         }
#       }
#     })
#   }

#   type = "kubernetes.io/dockerconfigjson"

#   depends_on = [azurerm_kubernetes_cluster.main]
# }


# resource "helm_release" "argocd" {
#   name       = "argo-cd"
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argo-cd"
#   namespace  = kubernetes_namespace.argocd.metadata[0].name
#   version    = "5.51.2"

#   depends_on = [
#     kubernetes_namespace.argocd,
#     kubernetes_secret.acr_secret
#   ]

#   # Example of customizing values.
#   # For a full list, check the official argo-cd helm chart documentation.
#   values = [
#     <<-EOT
#     server:
#       service:
#         type: LoadBalancer
#     controller:
#       metrics:
#         enabled: true
#     redis:
#       metrics:
#         enabled: true
#     repoServer:
#       metrics:
#         enabled: true
#     EOT
#   ]
# }
