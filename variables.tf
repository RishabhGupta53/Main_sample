
variable "resource_group_name" {
  type        = string
  description = "resource group name"
}

variable "location" {
  type        = string
  description = "azure region"
}

variable "allocation_method" {
  description = "Public IP allocation method"
  type        = string
  default     = "Static"
}

variable "rule_type" {
  description = "Type of request routing rule"
  type        = string
  default     = "Basic"
}

variable "sku" {
  description = "SKU for the public IP (Standard or Basic)"
  type        = string
  default     = "Standard"
}

variable "cert_name" {
  description = "Self signed certificate name"
  type        = string
  default     = "BimboConnect-COM"
}

variable "managed_identity" {
  description = "Managed Identity name"
  type        = string
  default     = "CBCOEOPMIDCD02"
}

variable "AppGateway" {
  type = map(object({
    application_gateway_name     = string
    port                         = string
    az_region                    = string
    tier                         = string
    autoscale_min_instance_count = string
    autoscale_max_instance_count = string
    capacity_type                = string
    manual_instance_count        = string
    availability_zone            = string
    backend_pool_name            = string
    listener_name                = string
    HTTP2                        = string
    hostname                     = string
    key_vault_name         = string
    key_vault_rg           = string
    # backend_ips            = string # Example: ["10.0.1.10", "10.0.1.11"]
    # backend_ip_required    = string
    # backend_fqdns          = string # Example: ["app.example.com", "test.example.com"]
    # backend_fqdns_required = string
    # backend_vm             = bool
    # backend_app_service    = bool
    listener_protocol      = string
    #app_service_name       = string
    vnet                   = string
    vnet_rg                = string
    subnet_name            = string
    backend_settings_name  = string
    rule_name              = string
    frontend_ip            = string
    private_ip_address     = string
    #private_subnet         = string
    # backend_vm_name        = string
    # backend_vm_nic         = string
    # backend_vm_rg          = string
    #app_service_rg = string
    firewall_policy_name   = string
    backend_pools_ip         = map(list(string))
    backend_pools_fqdn       = map(list(string))
    backend_pools_vm         = map(list(string))
    backend_pools_appservice = map(list(string))
  }))
}

variable "AppGateway_tags" {
  type = map(string)
}
