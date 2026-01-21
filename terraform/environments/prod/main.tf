terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "keystone-terraform-state-prod"
    prefix = "terraform/state/prod"
  }
}

module "security" {
  source = "../../modules/security"

  project_id  = var.project_id
  region      = var.region
  environment = "prod"
  app_name    = var.app_name
}

module "network" {
  source = "../../modules/network"

  project_id  = var.project_id
  region      = var.region
  environment = "prod"
  app_name    = var.app_name

  ssh_source_ranges    = var.ssh_source_ranges
  rate_limit_threshold = 2000
  connector_cidr       = "10.8.0.0/28"
}

module "compute" {
  source = "../../modules/compute"

  project_id        = var.project_id
  region            = var.region
  environment       = "prod"
  app_name          = var.app_name
  container_image   = var.container_image
  min_instances     = "1" # Always keep 1 instance warm
  max_instances     = "100"
  cpu_limit         = "2000m"
  memory_limit      = "1Gi"
  allow_public_access = var.allow_public_access
  vpc_connector_id  = module.network.connector_id

  enable_binary_authorization = true

  env_vars = {
    LOG_LEVEL = "info"
    DB_HOST   = module.database.private_ip_address
    DB_NAME   = module.database.database_name
  }
}

module "database" {
  source = "../../modules/database"

  project_id          = var.project_id
  region              = var.region
  environment         = "prod"
  app_name            = var.app_name
  tier                = "db-custom-2-7680" # 2 vCPU, 7.5GB RAM
  availability_type   = "REGIONAL" # High availability
  disk_size           = 100
  deletion_protection = true # Prevent accidental deletion
  vpc_id              = module.network.vpc_id
  kms_key_name        = module.security.db_kms_key_id
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id            = var.project_id
  region                = var.region
  environment           = "prod"
  app_name              = var.app_name
  service_name          = module.compute.service_name
  service_url           = module.compute.service_url
  notification_channels = var.notification_channels
  error_rate_threshold  = 0.01 # 1% error rate threshold
  latency_threshold_ms  = 500  # 500ms latency threshold
  kms_key_name          = module.security.storage_kms_key_id
}
