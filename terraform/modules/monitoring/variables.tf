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

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "service_url" {
  description = "Service URL for uptime checks"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
  default     = "/health"
}

variable "error_rate_threshold" {
  description = "Error rate threshold for alerts"
  type        = number
  default     = 0.05 # 5%
}

variable "latency_threshold_ms" {
  description = "Latency threshold in milliseconds"
  type        = number
  default     = 1000
}

variable "notification_channels" {
  description = "List of notification channel IDs"
  type        = list(string)
  default     = []
}

variable "kms_key_name" {
  description = "KMS key name for encryption"
  type        = string
  default     = null
}
