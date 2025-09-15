terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "adrwal-terraform-state"
    storage_account_name = "adrwalterraformstate"
    container_name       = "tfstate"
    key                  = "infra-k8s.terraform.tfstate"
  }
}


data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "adrwal-terraform-state"
    storage_account_name = "adrwalterraformstate"
    container_name       = "tfstate"
    key                  = "infra.terraform.tfstate"
  }
}



provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.kube_config.0.host
  client_certificate     = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.kube_config.0.cluster_ca_certificate)
}


resource "kubernetes_manifest" "argo-app" {
  manifest = yamldecode(file("${path.module}/../argo-app.yaml"))
}
