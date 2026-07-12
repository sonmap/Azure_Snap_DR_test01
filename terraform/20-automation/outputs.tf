output "automation_account_name" {
  value = azurerm_automation_account.this.name
}

output "automation_principal_id" {
  value = azurerm_automation_account.this.identity[0].principal_id
}

output "runbook_name" {
  value = azurerm_automation_runbook.snapshot_copy.name
}
