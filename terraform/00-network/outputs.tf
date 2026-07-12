output "primary_resource_group_name" {
  value = azurerm_resource_group.primary.name
}

output "dr_resource_group_name" {
  value = azurerm_resource_group.dr.name
}

output "automation_resource_group_name" {
  value = azurerm_resource_group.automation.name
}

output "global_resource_group_name" {
  value = azurerm_resource_group.global.name
}

output "primary_vnet_name" {
  value = azurerm_virtual_network.primary.name
}

output "dr_vnet_name" {
  value = azurerm_virtual_network.dr.name
}

output "primary_subnet_id" {
  value = azurerm_subnet.primary.id
}

output "dr_subnet_id" {
  value = azurerm_subnet.dr.id
}

output "primary_lb_name" {
  value = azurerm_lb.primary.name
}

output "dr_lb_name" {
  value = azurerm_lb.dr.name
}

output "primary_backend_pool_id" {
  value = azurerm_lb_backend_address_pool.primary.id
}

output "dr_backend_pool_id" {
  value = azurerm_lb_backend_address_pool.dr.id
}

output "primary_service_fqdn" {
  value = azurerm_public_ip.primary_service.fqdn
}

output "dr_service_fqdn" {
  value = azurerm_public_ip.dr_service.fqdn
}

output "traffic_manager_profile_name" {
  value = azurerm_traffic_manager_profile.app.name
}

output "traffic_manager_fqdn" {
  value = azurerm_traffic_manager_profile.app.fqdn
}

output "application_url" {
  value = "http://${azurerm_traffic_manager_profile.app.fqdn}:${var.application_port}/"
}
