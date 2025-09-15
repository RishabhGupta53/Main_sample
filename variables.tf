variable "location" {
  type        = string
  description = "Azure region where resources will be created"
  
  validation {
    condition     = length(var.location) > 0
    error_message = "Location cannot be empty."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._()-]{1,90}$", var.resource_group_name))
    error_message = "Resource group name must be 1-90 characters and can contain alphanumeric, underscore, parentheses, hyphen, and period characters."
  }
}

variable "StorageAccounts" {
  type = map(object({
    name                    = string
    account_tier           = string
    account_replication_type = string
    kind                   = string
    tls                    = string
    copy_scope            = string
    hns                   = bool
    sftp                  = bool
    nfs                   = bool
    access_tier           = string
    routing               = string
    infra_encrypt         = bool
    feed                  = bool
    versioning            = bool
    pep_subnet            = string
    pep_vnet              = string
    vnet_rg               = string
    static_website_enabled = string
  }))
  description = "Map of storage accounts to create"
  
  validation {
    condition = alltrue([
      for k, v in var.StorageAccounts : 
      can(regex("^[a-z0-9]{3,24}$", v.name))
    ])
    error_message = "Storage account names must be 3-24 characters long and contain only lowercase letters and numbers."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.StorageAccounts : 
      contains(["Standard", "Premium"], v.account_tier)
    ])
    error_message = "Account tier must be either 'Standard' or 'Premium'."
  }
}

variable "sto_tags" {
  type        = map(string)
  description = "Tags to apply to storage account resources"
  default     = {}
}

variable "enable_https" {
  type        = bool
  description = "Enable HTTPS traffic only"
  default     = true
}

variable "public_access" {
  type        = bool
  description = "Enable public network access"
  default     = false
}

variable "sas" {
  type        = bool
  description = "Enable shared access key"
  default     = true
}

variable "is_manual_connection" {
  type        = bool
  description = "Is the private endpoint connection manual"
  default     = false
}

variable "subresource_names" {
  type        = list(string)
  description = "List of subresource names for private endpoint"
  default     = ["blob"]
  
  validation {
    condition = alltrue([
      for name in var.subresource_names : 
      contains(["blob", "file", "web", "dfs"], name)
    ])
    error_message = "Subresource names must be one of: blob, file, web, dfs."
  }
}
