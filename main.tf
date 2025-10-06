---- Storage Account

#Last Modification 12/02/2024
#Created by NTT Cloud Team

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

resource "azurerm_storage_account" "sa" {
  for_each                          = var.StorageAccounts
  name                              = lower(each.value.name)
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = each.value.account_tier             // sku for the storage account possible values are "Standard" & "Premium"
  account_replication_type          = each.value.account_replication_type // Replication option for storage account, possible values are "LRS","GRS" & "ZRS"
  account_kind                      = each.value.kind                     // defines the kind of storage account possible values are "StorageV2" & "BlockBlobStorage"

  # Only set access_tier for Standard/StorageV2
  access_tier = (each.value.account_tier == "Standard" && each.value.kind == "StorageV2") ? each.value.access_tier : null

  public_network_access_enabled     = var.public_access
  shared_access_key_enabled         = var.sas
  min_tls_version                   = each.value.tls
  allowed_copy_scope                = each.value.copy_scope    // scope of copy operation for storage account, possible values are "AAD" & "Privatelink"
  is_hns_enabled = each.value.kind == "FileStorage" ? false : each.value.hns
  sftp_enabled = (each.value.kind == "FileStorage" ? false : (each.value.hns == true ? each.value.sftp : false))


  nfsv3_enabled = (
    each.value.kind != "FileStorage"
  ) ? (each.value.hns ? each.value.nfs : false) : null

  infrastructure_encryption_enabled = each.value.infra_encrypt // Infrastructure encryption required or not, possible values are true or false

  # --- Network Rules block added below ---
  network_rules {
    default_action = (
      each.value.kind != "FileStorage" && try(each.value.hns, false) && try(each.value.nfs, false) ? "Deny" : "Allow"
    )

    # Provide allowed IPs and/or VNET subnet IDs here.
    # You can parameterize these as variables if you want.
    ip_rules = var.storage_ip_rules
    virtual_network_subnet_ids = var.storage_vnet_subnet_ids

    bypass = ["AzureServices"]
  }
  # --- End Network Rules block ---

  dynamic "static_website" {
    for_each = (each.value.account_tier == "Standard" && each.value.kind == "StorageV2" && try(each.value.static_website_enabled, false)) ? [1] : []
    content {
      index_document     = "index.html"
      error_404_document = "404.html"
    }
  }

  dynamic "routing" {
    for_each = (
      each.value.kind == "StorageV2" || each.value.kind == "BlockBlobStorage"
    ) ? [1] : []
    content {
      choice = each.value.routing
    }
  }

  dynamic "blob_properties" {
    for_each = (
      each.value.kind == "StorageV2"
      || each.value.kind == "BlobStorage"
      || each.value.kind == "BlockBlobStorage"
    ) ? [1] : []
    content {
      delete_retention_policy {
        days = 7
      }
      versioning_enabled  = each.value.hns ? false : each.value.versioning
      change_feed_enabled = each.value.hns ? false : each.value.feed
      container_delete_retention_policy {
        days = 7
      }
    }
  }
  share_properties {
    retention_policy {
      days = 7
    }
  }

  tags = var.sto_tags

}

resource "azurerm_private_endpoint" "pep" {
  for_each            = var.StorageAccounts
  name                = "${azurerm_storage_account.sa[each.key].name}_pep"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = data.azurerm_subnet.subnet[each.key].id
  private_service_connection {
    name                           = "${azurerm_storage_account.sa[each.key].name}-pecon" // private service connection name with suffix pecon
    private_connection_resource_id = azurerm_storage_account.sa[each.key].id              // storage account ID for each storage account created
    is_manual_connection           = var.is_manual_connection
    subresource_names = lookup(local.storage_pe_subresource, each.value.kind, ["blob"])
  }
  tags = var.sto_tags
}





----------File share----------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30.0"
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

resource "azurerm_storage_share" "share1" {
  depends_on = [
    azurerm_private_endpoint.pep,
    null_resource.add_fs_a_record,
    null_resource.wait_for_dns
  ]
  for_each             = var.storageaccount_fileshare
  name                 = each.value.fs_share_name
  storage_account_id = data.azurerm_storage_account.existing[each.key].id

  # Only set quota and access_tier if supported by the account type
  quota = (
    each.value.account_tier == "Premium" && each.value.kind == "FileStorage"
      ? (each.value.fs_quota >= 100 && each.value.fs_quota % 100 == 0 ? each.value.fs_quota : 100)
    : each.value.fs_quota
  )

  access_tier = (
    each.value.account_tier == "Standard" && each.value.kind == "StorageV2"
      ? each.value.fs_share_access_tier
      : null
  )
}

resource "azurerm_private_endpoint" "pep" {
  for_each            = var.storageaccount_fileshare
  name                = "${each.value.fs_sto_name}_file_pep"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = data.azurerm_subnet.subnet[each.key].id
  private_service_connection {
    name                           = "${each.value.fs_sto_name}-pecon" // private service connection name with suffix pecon
    private_connection_resource_id = data.azurerm_storage_account.existing[each.key].id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }
  tags = var.fs_tags
}

resource "null_resource" "add_fs_a_record" {
  depends_on = [
    azurerm_private_endpoint.pep
  ]

  provisioner "local-exec" {
    command = <<EOT
    Set-Location '..\\..\\..\\Terraform\\Configuration\\FileShare_Parsing'; .\\FileShareDNSARecord.ps1 `
      -SubscriptionId $env:SubscriptionId `
      -tenantId $env:tenantId `
      -clientId $env:clientId `
      -secret $env:secret `
      -FileshareDnsZoneName $env:FileshareDnsZoneName `
      -RgDnsZoneName $env:RgDnsZoneName `
      -SubscriptionIdDNSZone $env:SubscriptionIdDNSZone `
      -tenantIdDNSZone $env:tenantIdDNSZone `
      -clientIdDNSZone $env:clientIdDNSZone `
      -secretDNSZone $env:secretDNSZone
EOT
    interpreter = [ "powershell", "-command" ]
  }
}

resource "null_resource" "wait_for_dns" {
  depends_on = [
    null_resource.add_fs_a_record,
    azurerm_private_endpoint.pep
  ]

  provisioner "local-exec" {
    command     = "start-sleep -Seconds 60"
    interpreter = ["powershell","-command"]
  }
}

resource "azurerm_backup_policy_file_share" "rsv_policy" {
  for_each = {
    for item in flatten([
      for fs_key, fs in var.storageaccount_fileshare : [
        for policy_key, backup_policy in fs.backup_policies : {
          key                        = "${fs_key}-${policy_key}"
          rsv_policy_name            = backup_policy.rsv_policy_name
          rsv_backup_frecuency       = backup_policy.rsv_backup_frecuency
          rsv_backup_time            = backup_policy.rsv_backup_time
          rsv_backup_timezone        = backup_policy.rsv_backup_timezone
          rsv_backup_retention_count = backup_policy.rsv_backup_retention_count
          rsv_backup_retention_text  = backup_policy.rsv_backup_retention_text
        }
      ]
    ]) : item.key => item
  }

  name                = each.value.rsv_policy_name
  resource_group_name = var.rsv_rg_name
  recovery_vault_name = var.rsv_name
  timezone            = each.value.rsv_backup_timezone

  backup {
    frequency = each.value.rsv_backup_frecuency
    time      = each.value.rsv_backup_time
  }

  dynamic "retention_daily" {
    for_each = contains(each.value.rsv_backup_retention_text, "Days") ? [1] : []
    content {
      count = each.value.rsv_backup_retention_count[
        index(each.value.rsv_backup_retention_text, "Days")
      ]
    }
  }

  dynamic "retention_monthly" {
    for_each = contains(each.value.rsv_backup_retention_text, "Months") ? [1] : []
    content {
      count    = each.value.rsv_backup_retention_count[
        index(each.value.rsv_backup_retention_text, "Months")
      ]
      weekdays = ["Sunday"]
      weeks    = ["Last"]
    }
  }
}

resource "azurerm_backup_container_storage_account" "container" {
  for_each = var.storageaccount_fileshare

  depends_on = [
    null_resource.wait_for_dns
  ]

  resource_group_name = var.rsv_rg_name
  recovery_vault_name = var.rsv_name

  storage_account_id = data.azurerm_storage_account.existing[each.key].id
}

resource "null_resource" "wait_after_registration" {
  depends_on = [azurerm_backup_container_storage_account.container]

  provisioner "local-exec" {
    command     = "Start-Sleep -Seconds 60"
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "azurerm_backup_protected_file_share" "protection" {
  depends_on = [
    azurerm_storage_share.share1,
    azurerm_backup_container_storage_account.container,
    null_resource.wait_after_registration
  ]

  for_each = {
    for item in flatten([
      for fs_key, fs in var.storageaccount_fileshare : [
        for policy_key, backup_policy in fs.backup_policies : {
          key         = "${fs_key}-${policy_key}"
          fs_name     = fs.fs_share_name
          sto_name    = fs.fs_sto_name
          fs_key      = fs_key
          policy_name = backup_policy.rsv_policy_name
        }
      ]
    ]) : item.key => item
  }

  resource_group_name        = var.rsv_rg_name
  recovery_vault_name        = var.rsv_name
  source_storage_account_id = data.azurerm_storage_account.existing[each.value.fs_key].id
  source_file_share_name = each.value.fs_name
  backup_policy_id = azurerm_backup_policy_file_share.rsv_policy[each.key].id
}
