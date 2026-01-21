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

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "ssh_source_ranges" {
  description = "Source IP ranges allowed for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per minute per IP)"
  type        = number
  default     = 1000
}

variable "blocked_ip_ranges" {
  description = "IP ranges to block (known malicious IPs)"
  type        = list(string)
  default     = []
}

variable "connector_cidr" {
  description = "CIDR range for VPC Serverless Connector (must be /28)"
  type        = string
  default     = "10.8.0.0/28"
}
