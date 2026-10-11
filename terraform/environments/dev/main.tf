terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "keystone-tf-state-PROJECT_ID-dev"
    prefix = "terraform/state"
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

  depends_on = [google_secret_manager_secret_version.configra_api_key]

  project_id          = var.project_id
  region              = var.region
  environment         = "dev"
  app_name            = var.app_name
  container_image     = var.container_image
  min_instances       = "0"
  max_instances       = "5"
  cpu_limit           = "1000m"
  memory_limit        = "512Mi"
  allow_public_access = true
  vpc_connector_id    = module.network.connector_id

  enable_binary_authorization = false # Disable for faster dev cycles

  env_vars = {
    LOG_LEVEL  = "debug"
    DB_HOST    = module.database.private_ip_address
    DB_PORT    = "5432"
    DB_USER    = module.database.database_user
    DB_NAME    = module.database.database_name
    DB_SSLMODE = "require"
  }

  secret_env_vars = {
    DB_PASSWORD = {
      secret_id = module.database.password_secret_id
      version   = "latest"
    }
    CONFIGRA_BOOTSTRAP_API_KEY = {
      secret_id = google_secret_manager_secret.configra_api_key.secret_id
      version   = "latest"
    }
  }
}

resource "random_password" "configra_api_key" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "configra_api_key" {
  project   = var.project_id
  secret_id = "${var.app_name}-dev-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "configra_api_key" {
  secret      = google_secret_manager_secret.configra_api_key.id
  secret_data = random_password.configra_api_key.result
}

module "database" {
  source = "../../modules/database"

  project_id          = var.project_id
  region              = var.region
  environment         = "dev"
  app_name            = var.app_name
  tier                = "db-f1-micro"
  availability_type   = "ZONAL"
  enable_public_ip    = false
  deletion_protection = false # Allow deletion in dev
  vpc_id              = module.network.vpc_id
  kms_key_name        = module.security.db_kms_key_id
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id   = var.project_id
  region       = var.region
  environment  = "dev"
  app_name     = var.app_name
  service_name = module.compute.service_name
  service_url  = module.compute.service_url
  kms_key_name = module.security.storage_kms_key_id
}
