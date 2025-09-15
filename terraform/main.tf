terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.44.0"
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
  #   network_rule_bypass_option    = "AzureServices"
  #   zone_redundancy_enabled       = false

  # Policies from the ARM template
  #   azuread_authentication_as_arm_policy_enabled = true
  # Retention, Trust, and Quarantine policies are disabled by default.
}

# Create an Azure Kubernetes Service (AKS) cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.resource_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${local.resource_name}-dns"
  #   kubernetes_version  = "1.32.6"

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
    # enable_auto_scaling   = false
    # enable_node_public_ip = false
    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    # network_policy      = "none"
    # load_balancer_sku   = "Standard"
    # outbound_type       = "loadBalancer"
    # pod_cidr            = "10.244.0.0/16"
    # service_cidr        = "10.0.0.0/16"
    # dns_service_ip      = "10.0.0.10"
    # load_balancer_profile {
    #   managed_outbound_ip_count = 1
    # }
  }

  #   kubelet_identity {
  #     client_id                 = var.user_assigned_identity_client_id
  #     object_id                 = var.user_assigned_identity_object_id
  #     user_assigned_identity_id = var.user_assigned_identity_id
  #   }

  # Cluster settings
  sku_tier = "Free"
  #   automatic_channel_upgrade         = "patch"
  #   node_os_channel_upgrade           = "NodeImage"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true

  #   storage_profile {
  #     disk_csi_driver_enabled     = true
  #     file_csi_driver_enabled     = true
  #     snapshot_controller_enabled = true
  #   }

  #   image_cleaner_enabled        = true
  #   image_cleaner_interval_hours = 168

  # This block is a direct equivalent of the windowsProfile in ARM
  #   windows_profile {
  #     admin_username = "azureuser"
  #   }
}

# Configure AKS Auto-Upgrade maintenance window
# resource "azurerm_kubernetes_cluster_maintenance_configuration" "autoupgrade" {
#   name                  = "aksManagedAutoUpgradeSchedule"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id

#   time_in_week {
#     day        = "Sunday"
#     hour_slots = [0, 1, 2, 3, 4, 5, 6, 7] # Represents 00:00-08:00
#   }
# }

# # Configure AKS Node OS Upgrade maintenance window
# resource "azurerm_kubernetes_cluster_maintenance_configuration" "nodeos" {
#   name                  = "aksManagedNodeOSUpgradeSchedule"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id

#   time_in_week {
#     day        = "Sunday"
#     hour_slots = [0, 1, 2, 3, 4, 5, 6, 7] # Represents 00:00-08:00
#   }
# }
