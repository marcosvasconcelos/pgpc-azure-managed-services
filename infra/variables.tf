variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "canadaeast"
}

variable "project_name" {
  description = "Base name for the project resources"
  type        = string
  default     = "strangler-fig"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "UT-Cloud-Computing"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
  default     = "P@ssw0rd1234!" # In production, input this via env var or secrets
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "db_password" {
  description = "Password for the MySQL database administrator"
  type        = string
  sensitive   = true
}
