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

  dynamic "backend_address_pool" {
    for_each = each.value.backend_ip_required ? [1] : []
    content {
      name         = each.value.backend_pool_ip
      ip_addresses = [each.value.backend_ips]
    }
  }

  # Add FQDN Backend Address Pool if backend_fqdns is defined
  dynamic "backend_address_pool" {
    for_each = each.value.backend_fqdns_required ? [1] : []
    content {
      name  = each.value.backend_pool_fqdn
      fqdns = [each.value.backend_fqdns]
    }
  }

  dynamic "backend_address_pool" {
    for_each = each.value.backend_vm ? [1] : []
    content {
      name         = each.value.backend_pool_vm
      ip_addresses = [data.azurerm_network_interface.existing_nic[each.key].private_ip_address]
    }
  }

  dynamic "backend_address_pool" {
    for_each = each.value.backend_app_service ? [1] : []
    content {
      name  = each.value.backend_pool_appservice
      fqdns = [data.azurerm_app_service.existing_apps[each.key].default_site_hostname]
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
