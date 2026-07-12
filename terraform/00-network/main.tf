locals {
  suffix             = lower(replace(substr(var.subscription_id, 0, 8), "-", ""))
  primary_rg_name    = "rg-${var.prefix}-prd-krc"
  dr_rg_name         = "rg-${var.prefix}-dr-jpe"
  automation_rg_name = "rg-${var.prefix}-auto-krc"
  global_rg_name     = "rg-${var.prefix}-global"
  primary_lb_name    = "lb-${var.prefix}-prd-krc"
  dr_lb_name         = "lb-${var.prefix}-dr-jpe"
  backend_pool_name  = "bepool-app"
}

resource "azurerm_resource_group" "primary" {
  name     = local.primary_rg_name
  location = var.primary_location
  tags     = var.tags
}

resource "azurerm_resource_group" "dr" {
  name     = local.dr_rg_name
  location = var.dr_location
  tags     = var.tags
}

resource "azurerm_resource_group" "automation" {
  name     = local.automation_rg_name
  location = var.primary_location
  tags     = var.tags
}

resource "azurerm_resource_group" "global" {
  name     = local.global_rg_name
  location = var.primary_location
  tags     = var.tags
}

resource "azurerm_virtual_network" "primary" {
  name                = "vnet-${var.prefix}-prd-krc"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  address_space       = var.primary_vnet_cidr
  tags                = var.tags
}

resource "azurerm_subnet" "primary" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = var.primary_subnet_cidr
}

resource "azurerm_network_security_group" "primary" {
  name                = "nsg-${var.prefix}-prd-app"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Tomcat-Client"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.application_port)
    source_address_prefix      = var.app_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-TrafficManager-Probe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.application_port)
    source_address_prefix      = "AzureTrafficManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-LoadBalancer-Probe"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.application_port)
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-MySQL-VNet"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "primary" {
  subnet_id                 = azurerm_subnet.primary.id
  network_security_group_id = azurerm_network_security_group.primary.id
}

resource "azurerm_virtual_network" "dr" {
  name                = "vnet-${var.prefix}-dr-jpe"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  address_space       = var.dr_vnet_cidr
  tags                = var.tags
}

resource "azurerm_subnet" "dr" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.dr.name
  virtual_network_name = azurerm_virtual_network.dr.name
  address_prefixes     = var.dr_subnet_cidr
}

resource "azurerm_network_security_group" "dr" {
  name                = "nsg-${var.prefix}-dr-app"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Tomcat-Client"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.application_port)
    source_address_prefix      = var.app_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-TrafficManager-Probe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.application_port)
    source_address_prefix      = "AzureTrafficManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-LoadBalancer-Probe"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.application_port)
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-MySQL-VNet"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dr" {
  subnet_id                 = azurerm_subnet.dr.id
  network_security_group_id = azurerm_network_security_group.dr.id
}

resource "azurerm_public_ip" "primary_service" {
  name                = "pip-${var.prefix}-prd-service-krc"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.prefix}-krc-${local.suffix}"
  tags                = var.tags
}

resource "azurerm_lb" "primary" {
  name                = local.primary_lb_name
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "fe-service"
    public_ip_address_id = azurerm_public_ip.primary_service.id
  }
}

resource "azurerm_lb_backend_address_pool" "primary" {
  name            = local.backend_pool_name
  loadbalancer_id = azurerm_lb.primary.id
}

resource "azurerm_lb_probe" "primary" {
  name                = "probe-tomcat-health"
  loadbalancer_id     = azurerm_lb.primary.id
  protocol            = "Http"
  port                = var.application_port
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "primary" {
  name                           = "rule-tomcat"
  loadbalancer_id                = azurerm_lb.primary.id
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  frontend_ip_configuration_name = "fe-service"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.primary.id]
  probe_id                       = azurerm_lb_probe.primary.id
  disable_outbound_snat          = true
}

resource "azurerm_public_ip" "dr_service" {
  name                = "pip-${var.prefix}-dr-service-jpe"
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.prefix}-jpe-${local.suffix}"
  tags                = var.tags
}

resource "azurerm_lb" "dr" {
  name                = local.dr_lb_name
  location            = azurerm_resource_group.dr.location
  resource_group_name = azurerm_resource_group.dr.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "fe-service"
    public_ip_address_id = azurerm_public_ip.dr_service.id
  }
}

resource "azurerm_lb_backend_address_pool" "dr" {
  name            = local.backend_pool_name
  loadbalancer_id = azurerm_lb.dr.id
}

resource "azurerm_lb_probe" "dr" {
  name                = "probe-tomcat-health"
  loadbalancer_id     = azurerm_lb.dr.id
  protocol            = "Http"
  port                = var.application_port
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "dr" {
  name                           = "rule-tomcat"
  loadbalancer_id                = azurerm_lb.dr.id
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  frontend_ip_configuration_name = "fe-service"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dr.id]
  probe_id                       = azurerm_lb_probe.dr.id
  disable_outbound_snat          = true
}

resource "azurerm_traffic_manager_profile" "app" {
  name                   = "tm-${var.prefix}-prod"
  resource_group_name    = azurerm_resource_group.global.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "${var.prefix}-${local.suffix}"
    ttl           = var.traffic_manager_ttl
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = var.application_port
    path                         = "/health"
    interval_in_seconds          = var.traffic_manager_probe_interval
    timeout_in_seconds           = var.traffic_manager_probe_interval == 10 ? 5 : 9
    tolerated_number_of_failures = 2
  }

  tags = var.tags
}

resource "azurerm_traffic_manager_azure_endpoint" "primary" {
  name               = "endpoint-krc"
  profile_id         = azurerm_traffic_manager_profile.app.id
  target_resource_id = azurerm_public_ip.primary_service.id
  priority           = 1
  enabled            = true

  lifecycle {
    ignore_changes = [enabled]
  }
}

resource "azurerm_traffic_manager_azure_endpoint" "dr" {
  name               = "endpoint-jpe"
  profile_id         = azurerm_traffic_manager_profile.app.id
  target_resource_id = azurerm_public_ip.dr_service.id
  priority           = 2
  enabled            = false

  lifecycle {
    ignore_changes = [enabled]
  }
}
