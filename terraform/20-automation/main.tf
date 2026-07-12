data "azurerm_resource_group" "automation" {
  name = var.automation_resource_group_name
}

data "azurerm_resource_group" "source" {
  name = var.source_resource_group_name
}

data "azurerm_resource_group" "target" {
  name = var.target_resource_group_name
}

resource "azurerm_automation_account" "this" {
  name                = var.automation_account_name
  location            = data.azurerm_resource_group.automation.location
  resource_group_name = data.azurerm_resource_group.automation.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "source_contributor" {
  scope                = data.azurerm_resource_group.source.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "target_contributor" {
  scope                = data.azurerm_resource_group.target.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

resource "azurerm_automation_runbook" "snapshot_copy" {
  name                    = "Copy-ManagedDiskSnapshots"
  location                = data.azurerm_resource_group.automation.location
  resource_group_name     = data.azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.this.name

  runbook_type = "PowerShell72"
  log_progress = true
  log_verbose  = true
  description  = "Quiesce a VM, create incremental snapshots, and copy them from Korea Central to Japan East."

  content = file("${path.module}/../../runbooks/Copy-ManagedDiskSnapshots.ps1")

  tags = var.tags
}

resource "azurerm_automation_schedule" "snapshot" {
  count = var.enable_schedule ? 1 : 0

  name                    = "snapshot-copy-every-${var.snapshot_interval_hour}-hours"
  resource_group_name     = data.azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Hour"
  interval                = var.snapshot_interval_hour
  timezone                = "Asia/Seoul"
  description             = "Periodic incremental snapshot copy to Japan East."
}

resource "azurerm_automation_job_schedule" "snapshot" {
  count = var.enable_schedule ? 1 : 0

  resource_group_name     = data.azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.this.name
  schedule_name           = azurerm_automation_schedule.snapshot[0].name
  runbook_name            = azurerm_automation_runbook.snapshot_copy.name

  parameters = {
    subscriptionid       = var.subscription_id
    sourceresourcegroup  = var.source_resource_group_name
    sourcevmname         = var.source_vm_name
    targetresourcegroup  = var.target_resource_group_name
    targetregion         = var.target_region
    retentiondays        = tostring(var.retention_days)
    waitforcopy          = tostring(var.wait_for_copy)
  }
}
