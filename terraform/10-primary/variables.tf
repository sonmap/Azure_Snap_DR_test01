variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type    = string
  default = "rg-snapdr-prd-krc"
}

variable "vnet_name" {
  type    = string
  default = "vnet-snapdr-prd-krc"
}

variable "subnet_name" {
  type    = string
  default = "snet-app"
}

variable "load_balancer_name" {
  type    = string
  default = "lb-snapdr-prd-krc"
}

variable "load_balancer_backend_pool_name" {
  type    = string
  default = "bepool-app"
}

variable "vm_name" {
  type    = string
  default = "vm-app-krc-01"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  description = "SSH public key path."
  type        = string
}

variable "vm_size" {
  description = "VM size available within both the subscription family quota and current regional capacity. Override in terraform.tfvars when required."
  type        = string
  default     = "Standard_D2s_v4"
}

variable "os_disk_size_gb" {
  type    = number
  default = 64
}

variable "data_disk_size_gb" {
  type    = number
  default = 64
}

variable "mysql_database" {
  type    = string
  default = "dr_demo"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "AzureSnapshotDR"
    ManagedBy = "Terraform"
    Role      = "Primary"
  }
}
