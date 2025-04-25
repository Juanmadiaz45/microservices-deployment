provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  
  # Use Azure CLI authentication
  use_cli = true
  # Skip provider registration to avoid permission issues
  skip_provider_registration = true
}

resource "azurerm_resource_group" "microservicesrg" {
  name     = var.resource_group_name
  location = var.location
}

module "networking" {
  source = "./modules/networking"

  location            = azurerm_resource_group.microservicesrg.location
  resource_group_name = azurerm_resource_group.microservicesrg.name
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnet_name         = var.subnet_name
  subnet_address_prefix = var.subnet_address_prefix
}

module "vm" {
  source = "./modules/microservices-vm"

  location            = azurerm_resource_group.microservicesrg.location
  resource_group_name = azurerm_resource_group.microservicesrg.name
  subnet_id           = module.networking.subnet_id
  vm_name             = var.vm_name
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
}

module "function_app" {
  source = "./modules/function-app"

  location            = azurerm_resource_group.microservicesrg.location
  resource_group_name = azurerm_resource_group.microservicesrg.name
  storage_account_name = "${lower(replace(var.resource_group_name, "-", ""))}funcstor2"
  function_app_name   = "${var.resource_group_name}-circuit-breaker2"
  microservices_vm_ip = module.vm.public_ip
}

module "ci_vm" {
  source = "./modules/vms/ci"

  location            = azurerm_resource_group.microservicesrg.location
  resource_group_name = azurerm_resource_group.microservicesrg.name
  subnet_id           = module.networking.subnet_id
  vm_name             = "ci-vm"
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
}