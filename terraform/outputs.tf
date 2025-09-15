output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "The login server URL of the Azure Container Registry."
}

output "acr_admin_username" {
  value       = azurerm_container_registry.main.admin_username
  description = "The admin username for the Azure Container Registry."
}

output "acr_admin_password" {
  value       = azurerm_container_registry.main.admin_password
  description = "The admin password for the Azure Container Registry."
  sensitive   = true
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.main.kube_config
  description = "The raw kubeconfig for the AKS cluster."
  sensitive   = true
}
