data "azurerm_resource_group" "primary" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "primary" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "primary" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.primary.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_lb" "primary" {
  name                = var.load_balancer_name
  resource_group_name = var.resource_group_name
}

data "azurerm_lb_backend_address_pool" "primary" {
  name            = var.load_balancer_backend_pool_name
  loadbalancer_id = data.azurerm_lb.primary.id
}

resource "azurerm_public_ip" "management" {
  name                = "pip-${var.vm_name}-mgmt"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "primary" {
  name                = "nic-${var.vm_name}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.primary.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.management.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "primary" {
  network_interface_id    = azurerm_network_interface.primary.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = data.azurerm_lb_backend_address_pool.primary.id
}

resource "azurerm_linux_virtual_machine" "primary" {
  name                = var.vm_name
  computer_name       = var.vm_name
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.primary.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "disk-${var.vm_name}-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(join("\n", [
    templatefile("${path.module}/cloud-init.yaml.tftpl", {
      mysql_database = var.mysql_database
    }),
    file("${path.module}/cloud-init-tail.yamlfrag")
  ]))

  boot_diagnostics {}

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_managed_disk" "mysql" {
  name                 = "disk-${var.vm_name}-mysql"
  location             = data.azurerm_resource_group.primary.location
  resource_group_name  = data.azurerm_resource_group.primary.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags = merge(var.tags, {
    DiskRole = "MySQL"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "mysql" {
  managed_disk_id    = azurerm_managed_disk.mysql.id
  virtual_machine_id = azurerm_linux_virtual_machine.primary.id
  lun                = 0
  caching            = "ReadOnly"
}
