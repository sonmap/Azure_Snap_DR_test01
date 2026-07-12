variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "snapdr"
}

variable "primary_location" {
  type    = string
  default = "koreacentral"
}

variable "dr_location" {
  type    = string
  default = "japaneast"
}

variable "primary_vnet_cidr" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "primary_subnet_cidr" {
  type    = list(string)
  default = ["10.10.10.0/24"]
}

variable "dr_vnet_cidr" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "dr_subnet_cidr" {
  type    = list(string)
  default = ["10.20.10.0/24"]
}

variable "admin_source_cidr" {
  description = "SSH management source CIDR. Use your public IP/32."
  type        = string
}

variable "app_source_cidr" {
  description = "Allowed source CIDR for Tomcat service traffic."
  type        = string
  default     = "0.0.0.0/0"
}

variable "application_port" {
  type    = number
  default = 8080
}

variable "traffic_manager_ttl" {
  type    = number
  default = 30
}

variable "traffic_manager_probe_interval" {
  description = "Traffic Manager monitor interval. Supported values are 10 or 30 seconds."
  type        = number
  default     = 30

  validation {
    condition     = contains([10, 30], var.traffic_manager_probe_interval)
    error_message = "traffic_manager_probe_interval must be 10 or 30."
  }
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "AzureSnapshotDR"
    ManagedBy = "Terraform"
  }
}
