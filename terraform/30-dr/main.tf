data "azurerm_resource_group" "dr" {
  name = var.dr_resource_group_name
}

data "azurerm_virtual_network" "dr" {
  name                = var.dr_vnet_name
  resource_group_name = var.dr_resource_group_name
}

data "azurerm_subnet" "dr" {
  name                 = var.dr_subnet_name
  virtual_network_name = data.azurerm_virtual_network.dr.name
  resource_group_name  = var.dr_resource_group_name
}

data "azurerm_lb" "dr" {
  name                = var.dr_load_balancer_name
  resource_group_name = var.dr_resource_group_name
}

data "azurerm_public_ip" "dr_service" {
  name                = var.dr_service_public_ip_name
  resource_group_name = var.dr_resource_group_name
}

data "external" "latest_snapshots" {
  program = [
    "python3",
    "${path.module}/../../scripts/find_latest_snapshot.py"
  ]

  query = {
    subscription_id     = var.subscription_id
    resource_group_name = var.dr_resource_group_name
    source_vm_name      = var.source_vm_name
  }
}

locals {
  recovery_set     = data.external.latest_snapshots.result.recovery_set
  os_snapshot_id   = data.external.latest_snapshots.result.os_snapshot_id
  data_snapshot_id = data.external.latest_snapshots.result.data_snapshot_id
  dr_backend_pool_id = one([
    for pool in data.azurerm_lb.dr.backend_address_pool : pool.id
    if pool.name == var.dr_backend_pool_name
  ])
}

resource "azurerm_managed_disk" "os" {
  name                 = "disk-${var.dr_vm_name}-os-${lower(local.recovery_set)}"
  location             = data.azurerm_resource_group.dr.location
  resource_group_name  = data.azurerm_resource_group.dr.name
  storage_account_type = var.os_disk_sku
  create_option        = "Copy"
  source_resource_id   = local.os_snapshot_id
  os_type              = "Linux"
  hyper_v_generation   = "V2"

  tags = merge(var.tags, {
    RecoverySet = local.recovery_set
    DiskRole    = "OS"
  })
}

resource "azurerm_managed_disk" "mysql" {
  name                 = "disk-${var.dr_vm_name}-mysql-${lower(local.recovery_set)}"
  location             = data.azurerm_resource_group.dr.location
  resource_group_name  = data.azurerm_resource_group.dr.name
  storage_account_type = var.data_disk_sku
  create_option        = "Copy"
  source_resource_id   = local.data_snapshot_id

  tags = merge(var.tags, {
    RecoverySet = local.recovery_set
    DiskRole    = "DATA-LUN-0"
  })
}

resource "azurerm_public_ip" "management" {
  name                = "pip-${var.dr_vm_name}-mgmt"
  location            = data.azurerm_resource_group.dr.location
  resource_group_name = data.azurerm_resource_group.dr.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "dr" {
  name                = "nic-${var.dr_vm_name}"
  location            = data.azurerm_resource_group.dr.location
  resource_group_name = data.azurerm_resource_group.dr.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.dr.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.management.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "dr" {
  network_interface_id    = azurerm_network_interface.dr.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = local.dr_backend_pool_id
}

resource "azurerm_virtual_machine" "dr" {
  name                  = var.dr_vm_name
  location              = data.azurerm_resource_group.dr.location
  resource_group_name   = data.azurerm_resource_group.dr.name
  network_interface_ids = [azurerm_network_interface.dr.id]
  vm_size               = var.vm_size

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name            = azurerm_managed_disk.os.name
    managed_disk_id = azurerm_managed_disk.os.id
    create_option   = "Attach"
    caching         = "ReadWrite"
    os_type         = "Linux"
  }

  tags = merge(var.tags, {
    RecoverySet = local.recovery_set
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "mysql" {
  managed_disk_id    = azurerm_managed_disk.mysql.id
  virtual_machine_id = azurerm_virtual_machine.dr.id
  lun                = 0
  caching            = "ReadOnly"
}

resource "azurerm_virtual_machine_extension" "start_services" {
  count = var.enable_start_extension ? 1 : 0

  name                 = "start-dr-services"
  virtual_machine_id   = azurerm_virtual_machine.dr.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    commandToExecute = "/bin/bash -lc 'sleep 20; /usr/local/sbin/dr-start-services.sh'"
  })

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.mysql,
    azurerm_network_interface_backend_address_pool_association.dr
  ]

  tags = var.tags
}
