output "function_app_name" {
  value = azurerm_windows_function_app.circuit_breaker.name
}

output "function_app_default_hostname" {
  value = azurerm_windows_function_app.circuit_breaker.default_hostname
}

output "function_app_endpoint" {
  value = "https://${azurerm_windows_function_app.circuit_breaker.default_hostname}/api/"
}