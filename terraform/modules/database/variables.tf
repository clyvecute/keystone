variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "Availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Disk type"
  type        = string
  default     = "PD_SSD"
}

variable "backup_retention_count" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "enable_public_ip" {
  description = "Enable public IP"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for private IP"
  type        = string
  default     = null
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "configra"
}

variable "database_user" {
  description = "Database user"
  type        = string
  default     = "configra_user"
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "kms_key_name" {
  description = "KMS key name for encryption (null for Google-managed encryption)"
  type        = string
  default     = null
}
