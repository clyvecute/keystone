variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "configra"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "cloud_run_min_instances" {
  description = "Minimum warm Cloud Run instances for production; tune against latency and cost measurements."
  type        = number
  default     = 1
  validation {
    condition     = var.cloud_run_min_instances >= 0 && var.cloud_run_min_instances <= 100
    error_message = "cloud_run_min_instances must be between 0 and 100."
  }
}

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances for production; keep within quota and database connection capacity."
  type        = number
  default     = 100
  validation {
    condition     = var.cloud_run_max_instances >= 1 && var.cloud_run_max_instances <= 1000
    error_message = "cloud_run_max_instances must be between 1 and 1000; confirm project quota before increasing it."
  }
}

variable "cloud_run_container_concurrency" {
  description = "Maximum simultaneous requests per Cloud Run instance; tune with representative load tests."
  type        = number
  default     = 80
  validation {
    condition     = var.cloud_run_container_concurrency >= 1 && var.cloud_run_container_concurrency <= 1000
    error_message = "cloud_run_container_concurrency must be between 1 and 1000."
  }
}

variable "allow_public_access" {
  description = "Allow public access to the service"
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "Source IP ranges allowed for SSH"
  type        = list(string)
  default     = [] # No SSH access by default in prod
}

variable "notification_channels" {
  description = "Notification channel IDs for alerts"
  type        = list(string)
  default     = []
}
