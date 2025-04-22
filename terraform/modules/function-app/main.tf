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
  sku_name            = "Y1"
}

resource "null_resource" "prepare_function_app" {
  triggers = {
    index_js_hash = filesha256("${path.module}/circuit-breaker/CircuitBreaker/index.js"),
    function_json_hash = filesha256("${path.module}/circuit-breaker/CircuitBreaker/function.json"),
    package_json_hash = filesha256("${path.module}/circuit-breaker/package.json"),
    host_json_hash = filesha256("${path.module}/circuit-breaker/host.json")
  }

  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/deploy
      mkdir -p ${path.module}/deploy
      cp -r ${path.module}/circuit-breaker/* ${path.module}/deploy/
      cd ${path.module}/deploy
      npm install --production
    EOT
  }
}

data "archive_file" "function_app_package" {
  type        = "zip"
  source_dir  = "${path.module}/deploy"
  output_path = "${path.module}/function-app.zip"
  depends_on  = [null_resource.prepare_function_app]
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
      node_version = "~20"
    }
    cors {
      allowed_origins = ["*"]
    }
    ftps_state = "Disabled"
  }
  
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"       = "1",
    "FUNCTIONS_WORKER_RUNTIME"       = "node",
    "MICROSERVICES_VM_IP"            = var.microservices_vm_ip,
    "AUTH_API_PORT"                  = "8000",
    "USERS_API_PORT"                 = "8083",
    "TODOS_API_PORT"                 = "8082",
    "FRONTEND_PORT"                  = "8080",
    "CIRCUIT_BREAKER_THRESHOLD"      = "3",
    "CIRCUIT_BREAKER_TIMEOUT_MS"     = "10000",
    "AzureWebJobsStorage"            = azurerm_storage_account.function_storage.primary_connection_string,
    "FUNCTIONS_EXTENSION_VERSION"    = "~4",
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true",
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~20"
  }

  zip_deploy_file = data.archive_file.function_app_package.output_path
}