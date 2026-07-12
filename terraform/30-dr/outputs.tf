output "recovery_set" {
  value = local.recovery_set
}

output "management_public_ip" {
  value = azurerm_public_ip.management.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.dr.private_ip_address
}

output "vm_id" {
  value = azurerm_virtual_machine.dr.id
}

output "dr_service_fqdn" {
  value = data.azurerm_public_ip.dr_service.fqdn
}

output "dr_health_url" {
  value = "http://${data.azurerm_public_ip.dr_service.fqdn}:8080/health"
}
