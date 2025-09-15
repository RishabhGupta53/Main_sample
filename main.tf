# Last Modification 12/02/2024
# Created by NTT Cloud Team

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0.0"
    }
  }
  required_version = ">= 1.1.0"
  
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  storage_pe_subresource = {
    StorageV2         = ["blob"]
    BlockBlobStorage  = ["blob"]
    FileStorage       = ["file"]
  }
  
  # Validate storage account names
  storage_accounts_validated = {
    for k, v in var.StorageAccounts : k => v
    if can(regex("^[a-z0-9]{3,24}$", v.name))
  }
}

data "azurerm_subnet" "subnet" {
  for_each             = local.storage_accounts_validated
  name                 = each.value.pep_subnet
  virtual_network_name = each.value.pep_vnet
  resource_group_name  = each.value.vnet_rg
}

data "azurerm_virtual_network" "vnet" {
  for_each            = local.storage_accounts_validated
  name                = each.value.pep_vnet
  resource_group_name = each.value.vnet_rg
}

resource "azurerm_storage_account" "sa" {
  for_each                          = local.storage_accounts_validated
  name                              = each.value.name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = each.value.account_tier
  account_replication_type          = each.value.account_replication_type
  account_kind                      = each.value.kind

  # Conditional access_tier - only for Standard StorageV2
  access_tier = (
    each.value.account_tier == "Standard" && 
    each.value.kind == "StorageV2" && 
    each.value.access_tier != null
  ) ? each.value.access_tier : null

  public_network_access_enabled = var.public_access
  shared_access_key_enabled     = var.sas
  https_traffic_only_enabled    = var.enable_https
  min_tls_version               = each.value.tls
  allowed_copy_scope            = each.value.copy_scope != "" ? each.value.copy_scope : null
  is_hns_enabled                = each.value.hns
  sftp_enabled                  = each.value.sftp

  # Conditional nfsv3_enabled - only for Premium FileStorage
  nfsv3_enabled = (
    each.value.account_tier == "Premium" && 
    each.value.kind == "FileStorage"
  ) ? each.value.nfs : null

  infrastructure_encryption_enabled = each.value.infra_encrypt

  # Static website - only for Standard StorageV2
  dynamic "static_website" {
    for_each = (
      each.value.account_tier == "Standard" && 
      each.value.kind == "StorageV2" && 
      each.value.static_website_enabled == "true"
    ) ? [1] : []
    
    content {
      index_document     = "index.html"
      error_404_document = "404.html"
    }
  }

  # Routing - for StorageV2 and BlockBlobStorage
  dynamic "routing" {
    for_each = (
      each.value.kind == "StorageV2" || 
      each.value.kind == "BlockBlobStorage"
    ) ? [1] : []
    
    content {
      choice = each.value.routing
    }
  }

  # Blob properties - for blob-supporting kinds
  dynamic "blob_properties" {
    for_each = (
      each.value.kind == "StorageV2" ||
      each.value.kind == "BlobStorage" ||
      each.value.kind == "BlockBlobStorage"
    ) ? [1] : []
    
    content {
      versioning_enabled  = each.value.versioning
      change_feed_enabled = each.value.feed
      
      delete_retention_policy {
        days = 7
      }
      
      container_delete_retention_policy {
        days = 7
      }
    }
  }

  tags = var.sto_tags

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags["Launch_Date"]
    ]
  }
}

resource "azurerm_private_endpoint" "pep" {
  for_each            = local.storage_accounts_validated
  name                = "${azurerm_storage_account.sa[each.key].name}-pep"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = data.azurerm_subnet.subnet[each.key].id

  private_service_connection {
    name                           = "${azurerm_storage_account.sa[each.key].name}-pecon"
    private_connection_resource_id = azurerm_storage_account.sa[each.key].id
    is_manual_connection           = var.is_manual_connection
    subresource_names              = lookup(local.storage_pe_subresource, each.value.kind, var.subresource_names)
  }

  tags = var.sto_tags
}

# Outputs for reference
output "storage_accounts" {
  description = "Created storage accounts"
  value = {
    for k, v in azurerm_storage_account.sa : k => {
      id                  = v.id
      name                = v.name
      primary_access_key  = v.primary_access_key
      connection_string   = v.primary_connection_string
    }
  }
  sensitive = true
}

output "private_endpoints" {
  description = "Created private endpoints"
  value = {
    for k, v in azurerm_private_endpoint.pep : k => {
      id   = v.id
      name = v.name
      private_service_connection = v.private_service_connection[0].private_ip_address
    }
  }
}
