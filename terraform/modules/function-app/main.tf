resource "azurerm_storage_account" "function_storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "function_plan" {
  name                = var.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = "Y1" # Consumption plan
}

resource "azurerm_windows_function_app" "circuit_breaker" {
  name                       = var.function_app_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id
  
  site_config {
    application_stack {
      node_version = "~18"
    }
    cors {
      allowed_origins = ["*"]
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"    = "1",
    "FUNCTIONS_WORKER_RUNTIME"    = "node",
    "MICROSERVICES_VM_IP"         = var.microservices_vm_ip,
    "AUTH_API_PORT"               = "8000",
    "USERS_API_PORT"              = "8083",
    "TODOS_API_PORT"              = "8082",
    "FRONTEND_PORT"               = "8080",
    "CIRCUIT_BREAKER_THRESHOLD"   = "3",
    "CIRCUIT_BREAKER_TIMEOUT_MS"  = "10000"
  }
}