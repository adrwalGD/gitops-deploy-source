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
