output "ci_public_ip" {
  value = azurerm_public_ip.ci_public_ip.ip_address
}
