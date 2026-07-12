output "vm_id" {
  value = azurerm_linux_virtual_machine.primary.id
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.primary.name
}

output "management_public_ip" {
  value = azurerm_public_ip.management.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.primary.private_ip_address
}

output "os_disk_name" {
  value = azurerm_linux_virtual_machine.primary.os_disk[0].name
}

output "mysql_data_disk_id" {
  value = azurerm_managed_disk.mysql.id
}
