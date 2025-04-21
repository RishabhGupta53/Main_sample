resource "azurerm_application_gateway" "agw" {
  for_each = var.AppGateway
  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.location
  ...

  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_ip, {})
    content {
      name = backend_address_pool.key
      backend_addresses = [
        for ip in backend_address_pool.value : {
          ip_address = ip
        }
      ]
    }
  }

  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_fqdn, {})
    content {
      name = backend_address_pool.key
      backend_addresses = [
        for fqdn in backend_address_pool.value : {
          fqdn = fqdn
        }
      ]
    }
  }

  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_vm, {})
    content {
      name = backend_address_pool.key
      backend_addresses = [
        for nic_id in backend_address_pool.value : {
          ip_address = data.azurerm_network_interface.vm_nics[nic_id].ip_configuration[0].private_ip_address
        }
      ]
    }
  }

  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_appservice, {})
    content {
      name = backend_address_pool.key
      fqdns = [
        for app in backend_address_pool.value :
        try(
          data.azurerm_windows_web_app.app_services_windows["${each.key}_${backend_address_pool.key}_${app}"].default_hostname,
          data.azurerm_linux_web_app.app_services_linux["${each.key}_${backend_address_pool.key}_${app}"].default_hostname
        )
      ]
    }
  }

  ...
}





data "azurerm_windows_web_app" "app_services_windows" {
  for_each = {
    for item in flatten([
      for gw_key, gw in var.AppGateway : [
        for app_pool_key, app_names in try(gw.backend_pools_appservice, {}) : [
          for app in app_names : {
            key = "${gw_key}_${app_pool_key}_${app}"
            name = app
            resource_group_name = var.resource_group_name
          }
        ]
      ]
    ]) : item.key => item
  }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

data "azurerm_linux_web_app" "app_services_linux" {
  for_each = {
    for item in flatten([
      for gw_key, gw in var.AppGateway : [
        for app_pool_key, app_names in try(gw.backend_pools_appservice, {}) : [
          for app in app_names : {
            key = "${gw_key}_${app_pool_key}_${app}"
            name = app
            resource_group_name = var.resource_group_name
          }
        ]
      ]
    ]) : item.key => item
  }

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}
data "azurerm_network_interface" "vm_nics" {
  for_each = toset(flatten([
    for gw in var.AppGateway :
    flatten([
      for vm_pool in try(gw.backend_pools_vm, {}) :
      keys(vm_pool)
    ])
  ]))

  name                = each.value
  resource_group_name = var.resource_group_name
}
