variable "subscription_id" {
  type = string
}

variable "automation_resource_group_name" {
  type    = string
  default = "rg-snapdr-auto-krc"
}

variable "source_resource_group_name" {
  type    = string
  default = "rg-snapdr-prd-krc"
}

variable "target_resource_group_name" {
  type    = string
  default = "rg-snapdr-dr-jpe"
}

variable "source_vm_name" {
  type    = string
  default = "vm-app-krc-01"
}

variable "target_region" {
  type    = string
  default = "japaneast"
}

variable "automation_account_name" {
  type    = string
  default = "aa-snapdr-krc"
}

variable "enable_schedule" {
  description = "Enable periodic snapshot copy. Keep false until manual test succeeds."
  type        = bool
  default     = false
}

variable "snapshot_interval_hour" {
  type    = number
  default = 4
}

variable "retention_days" {
  type    = number
  default = 7
}

variable "wait_for_copy" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "AzureSnapshotDR"
    ManagedBy = "Terraform"
  }
}
