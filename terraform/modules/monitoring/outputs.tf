output "monitoring_bucket" {
  description = "Monitoring bucket name"
  value       = google_storage_bucket.monitoring.name
}

output "uptime_check_id" {
  description = "Uptime check ID"
  value       = var.service_url != "" ? google_monitoring_uptime_check_config.service[0].uptime_check_id : null
}
