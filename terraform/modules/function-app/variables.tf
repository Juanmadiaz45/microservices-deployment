variable "location" {
  type        = string
  description = "Azure region where the function app will be created"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "storage_account_name" {
  type        = string
  description = "Name of the storage account for the function app"
  default     = "microservicesfuncstorage"
}

variable "app_service_plan_name" {
  type        = string
  description = "Name of the app service plan"
  default     = "microservices-func-plan"
}

variable "function_app_name" {
  type        = string
  description = "Name of the function app"
  default     = "microservices-circuit-breaker"
}

variable "microservices_vm_ip" {
  type        = string
  description = "Public IP address of the microservices VM"
}