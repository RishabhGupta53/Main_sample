resource "azurerm_application_gateway" "agw" {
  # ... other configuration like name, location, sku, etc.

  for_each = var.AppGateway

  backend_address_pool {
    name = "${each.key}_ip_pool"
    dynamic "backend_addresses" {
      for_each = contains(keys(each.value), "backend_pools_ip") && each.value.backend_pools_ip != null ? flatten([
        for pool in values(each.value.backend_pools_ip) : [
          for ip in pool : { ip_address = ip }
        ]
      ]) : []

      content {
        ip_address = backend_addresses.value.ip_address
      }
    }
  }

  backend_address_pool {
    name = "${each.key}_fqdn_pool"
    dynamic "backend_addresses" {
      for_each = contains(keys(each.value), "backend_pools_fqdn") && each.value.backend_pools_fqdn != null ? flatten([
        for pool in values(each.value.backend_pools_fqdn) : [
          for fqdn in pool : { fqdn = fqdn }
        ]
      ]) : []

      content {
        fqdn = backend_addresses.value.fqdn
      }
    }
  }

  backend_address_pool {
    name = "${each.key}_vm_pool"
    dynamic "backend_addresses" {
      for_each = contains(keys(each.value), "backend_pools_vm") && each.value.backend_pools_vm != null ? flatten([
        for pool in values(each.value.backend_pools_vm) : [
          for vm in pool : { fqdn = "${vm}.internal.cloudapp.net" }  # Modify FQDN logic if needed
        ]
      ]) : []

      content {
        fqdn = backend_addresses.value.fqdn
      }
    }
  }

  backend_address_pool {
    name = "${each.key}_appsvc_pool"
    dynamic "backend_addresses" {
      for_each = contains(keys(each.value), "backend_pools_appservice") && each.value.backend_pools_appservice != null ? flatten([
        for pool in values(each.value.backend_pools_appservice) : [
          for app in pool : { fqdn = data.azurerm_app_service.app_services["${each.key}_${app}"].default_site_hostname }
        ]
      ]) : []

      content {
        fqdn = backend_addresses.value.fqdn
      }
    }
  }

  # Make sure you include the related data blocks if using App Services
  dynamic "backend_http_settings" {
    for_each = [each.value]  # You’ll want to conditionally configure this too
    content {
      name                                = each.value.backend_settings_name
      port                                = tonumber(each.value.port)
      protocol                            = upper(each.value.listener_protocol)
      pick_host_name_from_backend_address = true
      request_timeout                     = 30
    }
  }

  # more config...
}




data "azurerm_app_service" "app_services" {
  for_each            = toset(flatten([
    for gw_key, gw in var.AppGateway : [
      for app in flatten(values(gw.backend_pools_appservice)) : "${gw_key}_${app}"
    ]
  ]))
  name                = split("_", each.key)[1]
  resource_group_name = var.AppGateway[split("_", each.key)[0]].backend_app_service_rg
}
