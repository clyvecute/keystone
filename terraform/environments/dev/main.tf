terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "keystone-terraform-state-dev"
    prefix = "terraform/state/dev"
  }
}

module "security" {
  source = "../../modules/security"

  project_id  = var.project_id
  region      = var.region
  environment = "dev"
  app_name    = var.app_name
}

module "network" {
  source = "../../modules/network"

  project_id  = var.project_id
  region      = var.region
  environment = "dev"
  app_name    = var.app_name

  rate_limit_threshold = 5000
  connector_cidr       = "10.8.0.16/28"
}

module "compute" {
  source = "../../modules/compute"

  project_id        = var.project_id
  region            = var.region
  environment       = "dev"
  app_name          = var.app_name
  container_image   = var.container_image
  min_instances     = "0"
  max_instances     = "5"
  cpu_limit         = "1000m"
  memory_limit      = "512Mi"
  allow_public_access = true
  vpc_connector_id  = module.network.connector_id

  enable_binary_authorization = false # Disable for faster dev cycles

  env_vars = {
    LOG_LEVEL = "debug"
    DB_HOST   = module.database.private_ip_address
    DB_NAME   = module.database.database_name
  }
}

module "database" {
  source = "../../modules/database"

  project_id          = var.project_id
  region              = var.region
  environment         = "dev"
  app_name            = var.app_name
  tier                = "db-f1-micro"
  availability_type   = "ZONAL"
  deletion_protection = false # Allow deletion in dev
  vpc_id              = module.network.vpc_id
  kms_key_name        = module.security.db_kms_key_id
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id      = var.project_id
  region          = var.region
  environment     = "dev"
  app_name        = var.app_name
  service_name    = module.compute.service_name
  service_url     = module.compute.service_url
  kms_key_name    = module.security.storage_kms_key_id
}
