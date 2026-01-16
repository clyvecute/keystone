output "service_url" {
  description = "Cloud Run service URL"
  value       = module.compute.service_url
}

output "database_connection" {
  description = "Database connection name"
  value       = module.database.instance_connection_name
}

output "monitoring_bucket" {
  description = "Monitoring bucket"
  value       = module.monitoring.monitoring_bucket
}
