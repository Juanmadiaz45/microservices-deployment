variable "location" {
  type        = string
}

variable "resource_group_name" {
  type        = string
}

variable "vnet_name" {
  type        = string
  default     = "microservicesvnet"
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  type        = string
  default     = "microservicessubnet"
}

variable "subnet_address_prefix" {
  type        = list(string)
  default     = ["10.0.2.0/24"]
}