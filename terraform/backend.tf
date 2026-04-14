terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state configuration
  # Uncomment and configure after creating the state bucket
  # backend "gcs" {
  #   bucket = "keystone-tf-state-<PROJECT_ID>-<ENV>"
  #   prefix = "terraform/state"
  # }
}
