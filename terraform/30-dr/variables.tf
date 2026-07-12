variable "subscription_id" {
  type = string
}

variable "dr_resource_group_name" {
  type    = string
  default = "rg-snapdr-dr-jpe"
}

variable "dr_vnet_name" {
  type    = string
  default = "vnet-snapdr-dr-jpe"
}

variable "dr_subnet_name" {
  type    = string
  default = "snet-app"
}

variable "dr_load_balancer_name" {
  type    = string
  default = "lb-snapdr-dr-jpe"
}

variable "dr_backend_pool_name" {
  type    = string
  default = "bepool-app"
}

variable "dr_service_public_ip_name" {
  type    = string
  default = "pip-snapdr-dr-service-jpe"
}

variable "source_vm_name" {
  type    = string
  default = "vm-app-krc-01"
}

variable "dr_vm_name" {
  type    = string
  default = "vm-app-jpe-dr-01"
}

variable "vm_size" {
  description = "DR VM size available within both the subscription family quota and current Japan East capacity. Override in terraform.tfvars when required."
  type        = string
  default     = "Standard_D2s_v4"
}

variable "os_disk_sku" {
  type    = string
  default = "StandardSSD_LRS"
}

variable "data_disk_sku" {
  type    = string
  default = "StandardSSD_LRS"
}

variable "enable_start_extension" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "AzureSnapshotDR"
    ManagedBy = "Terraform"
    Role      = "DR"
  }
}
