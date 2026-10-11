output "service_url" {
  description = "Cloud Run service URL"
  value       = module.compute.service_url
}

output "database_connection" {
  description = "Database connection name"
  value       = module.database.instance_connection_name
}

output "configra_api_key_secret_id" {
  description = "Secret Manager secret ID to grant to Configra API callers"
  value       = google_secret_manager_secret.configra_api_key.secret_id
}

output "monitoring_bucket" {
  description = "Monitoring bucket"
  value       = module.monitoring.monitoring_bucket
}
