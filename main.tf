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

resource "azurerm_public_ip" "public_ip" {
  for_each            = var.AppGateway
  name                = "${each.value.application_gateway_name}_pip"
  location            = each.value.az_region
  resource_group_name = var.resource_group_name
  allocation_method   = var.allocation_method
  sku                 = var.sku
  zones = local.zone_list[each.key]
  tags  = var.AppGateway_tags
}

resource "azurerm_web_application_firewall_policy" "firewall_policy" {
  for_each            = var.AppGateway
  name                = each.value.firewall_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    mode = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
  tags = var.AppGateway_tags
}

resource "azurerm_application_gateway" "agw" {
  for_each            = var.AppGateway
  name                = each.value.application_gateway_name
  location            = each.value.az_region
  resource_group_name = var.resource_group_name
  enable_http2        = each.value.HTTP2 == "Enabled" ? true : false
  zones               = local.zone_list[each.key]


  sku {
    name     = each.value.tier
    tier     = each.value.tier
    capacity = each.value.capacity_type == "Manual" ? each.value.manual_instance_count : null
  }
  #Only create an autoscale_configuration block if the capacity_type is “Autoscale”
  dynamic "autoscale_configuration" {
    for_each = each.value.capacity_type == "Autoscale" ? [each.value] : []
    content {
      min_capacity = each.value.autoscale_min_instance_count
      max_capacity = each.value.autoscale_max_instance_count
    }
  }

  # Attach WAF Policy only if tier is "WAF_v2"
  firewall_policy_id = each.value.tier == "WAF_v2" ? azurerm_web_application_firewall_policy.firewall_policy[each.key].id : null

  gateway_ip_configuration {
    name      = "${each.value.application_gateway_name}_ipconfig"
    subnet_id = data.azurerm_subnet.subnet[each.key].id
  }

  frontend_ip_configuration {
    name                 = "${each.value.application_gateway_name}_frontend_public"
    public_ip_address_id = azurerm_public_ip.public_ip[each.key].id
  }

  # Private IP Configuration (Only included if create_ip is "both")
  dynamic "frontend_ip_configuration" {
    for_each = each.value.frontend_ip == "both" ? [1] : []
    content {
      name                          = "${each.value.application_gateway_name}_frontend_private"
      subnet_id                     = data.azurerm_subnet.subnet[each.key].id
      private_ip_address_allocation = var.allocation_method
      private_ip_address            = each.value.private_ip_address
    }
  }

  frontend_port {
    name = "frontendPort"
    port = each.value.port
  }

  ssl_certificate {
    name                = var.cert_name
    key_vault_secret_id = data.azurerm_key_vault_certificate.certificate[each.key].versionless_secret_id
  }

  http_listener {
    name                           = each.value.listener_name
    frontend_ip_configuration_name = each.value.frontend_ip == "public" ? "${each.value.application_gateway_name}_frontend_public" : "${each.value.application_gateway_name}_frontend_private"
    frontend_port_name             = "frontendPort"
    protocol                       = each.value.listener_protocol
    host_name                      = length(each.value.hostname) > 0 ? each.value.hostname : null
    ssl_certificate_name           = var.cert_name
  }

  # Backend Pools from IPs
  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_ip, {})
    content {
      name         = key
      ip_addresses = value
    }
  }

  # Backend Pools from FQDNs
  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_fqdn, {})
    content {
      name  = key
      fqdns = value
    }
  }

  # Backend Pools from VMs
  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_vm, {})
    content {
      name         = key
      ip_addresses = [for vm in value : data.azurerm_network_interface.vm_nics["${each.key}_${vm}"].private_ip_address]
    }
  }

  # Backend Pools from App Services
  dynamic "backend_address_pool" {
    for_each = try(each.value.backend_pools_appservice, {})
    content {
      name  = key
      fqdns = [for app in value : data.azurerm_app_service.app_services["${each.key}_${app}"].default_site_hostname]
    }
  }

  backend_http_settings {
    name                  = each.value.backend_settings_name
    cookie_based_affinity = "Disabled"
    port                  = each.value.port
    protocol              = each.value.listener_protocol
    request_timeout       = 60
  }

  request_routing_rule {
    name                       = each.value.rule_name
    rule_type                  = var.rule_type
    http_listener_name         = each.value.listener_name
    backend_address_pool_name  = each.value.backend_pool_name
    backend_http_settings_name = each.value.backend_settings_name
    priority                   = 100
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.identity[each.key].id]
  }
  tags = var.AppGateway_tags
}
