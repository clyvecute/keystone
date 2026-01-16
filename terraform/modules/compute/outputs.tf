output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_service.app.status[0].url
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_service.app.name
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.app.email
}
