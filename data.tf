# Data Block to Fetch Existing Virtual Network
data "azurerm_virtual_network" "vnet" {
  for_each            = var.AppGateway
  name                = each.value.vnet
  resource_group_name = each.value.vnet_rg
}

# Data Block to Fetch Existing Subnet
data "azurerm_subnet" "subnet" {
  for_each             = var.AppGateway
  name                 = each.value.subnet_name
  virtual_network_name = each.value.vnet
  resource_group_name  = each.value.vnet_rg
}

data "azurerm_user_assigned_identity" "identity" {
  for_each            = var.AppGateway
  name                = var.managed_identity
  resource_group_name = each.value.key_vault_rg
}

# Data source to get the Key Vault
data "azurerm_key_vault" "kv" {
  for_each            = var.AppGateway
  name                = each.value.key_vault_name
  resource_group_name = each.value.key_vault_rg
}

# Data source to get the certificate from Key Vault
data "azurerm_key_vault_certificate" "certificate" {
  for_each     = var.AppGateway
  name         = var.cert_name
  key_vault_id = data.azurerm_key_vault.kv[each.key].id
}

# Fetch Existing VM's Network Interface
# data "azurerm_network_interface" "existing_nic" {
#   for_each            = { for key, value in var.AppGateway : key => value if value.backend_vm }
#   name                = each.value.backend_vm_nic
#   resource_group_name = each.value.backend_vm_rg
# }

# # Data Block to Fetch Existing App Service
# data "azurerm_app_service" "existing_apps" {
#   for_each            = { for key, value in var.AppGateway : key => value if value.backend_app_service }
#   name                = each.value.app_service_name
#   resource_group_name = each.value.app_service_rg
# }

data "azurerm_network_interface" "vm_nics" {
  for_each = {
    for item in flatten([
      for gw_key, gw in var.AppGateway : [
        for vm_pool_key, vm_names in gw.backend_pools_vm : [
          for vm in vm_names : {
            key   = "${gw_key}_${vm_pool_key}_${vm}"
            name  = gw.backend_vm_nic
            rg    = var.resource_group_name
          }
        ]
      ]
    ]) : item.key => {
      name                = item.name
      resource_group_name = item.rg
    }
  }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}
data "azurerm_app_service" "app_services" {
  for_each = {
    for item in flatten([
      for gw_key, gw in var.AppGateway : [
        for app_pool_key, app_names in gw.backend_pools_appservice : [
          for app in app_names : {
            key   = "${gw_key}_${app_pool_key}_${app}"
            name  = app
            rg    = var.resource_group_name
          }
        ]
      ]
    ]) : item.key => {
      name                = item.name
      resource_group_name = item.rg
    }
  }

  name                = each.value.name
  #resource_group_name = each.value.resource_group_name
  resource_group_name = "rg-gbconectedbbu-dev-eus2"
}
