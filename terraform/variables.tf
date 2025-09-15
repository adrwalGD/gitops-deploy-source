variable "resources_name_prefix" {
  type        = string
  description = "The name prefix for all resources."
  default     = "adrwalgitops"
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed."
  default     = "westeurope"
}

# variable "acr_name_prefix" {
#   type        = string
#   description = "The name of the Azure Container Registry."
#   default     = "adrwalgitops"
# }

# variable "aks_cluster_name_prefix" {
#   type        = string
#   description = "The name of the Azure Kubernetes Service cluster."
#   default     = "adrwal-k8s"
# }

# variable "user_assigned_identity_id" {
#   type        = string
#   description = "The resource ID of the user-assigned identity for the kubelet."
#   # Note: The original ARM template had a hardcoded value.
#   # It's better practice to create this identity in Terraform or use a data source to fetch it.
#   # For this conversion, the value is taken from the ARM template parameters.
#   default = "/subscriptions/afa1a461-3f97-478d-a062-c8db00c98741/resourceGroups/MC_adrwal-gitops_adrwal-k8s_westeurope/providers/Microsoft.ManagedIdentity/userAssignedIdentities/adrwal-k8s-agentpool"
# }

# variable "user_assigned_identity_client_id" {
#   type        = string
#   description = "The client ID of the user-assigned identity for the kubelet."
#   default     = "6297e2e8-ff69-492d-88dd-274115a94d6b" # From ARM template
# }

# variable "user_assigned_identity_object_id" {
#   type        = string
#   description = "The object ID of the user-assigned identity for the kubelet."
#   default     = "da00fb76-c325-4fbd-a9bf-5710c12cb3bf" # From ARM template
# }
