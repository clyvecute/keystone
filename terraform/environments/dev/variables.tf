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
  default     = "gcr.io/cloudrun/hello"
}
