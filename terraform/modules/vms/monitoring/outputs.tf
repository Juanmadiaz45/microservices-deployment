output "monitoring_public_ip" {
  value = azurerm_public_ip.monitoring_public_ip.ip_address
}
