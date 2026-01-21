# Security Logging and Audit
# Ships critical audit logs to BigQuery for long-term analysis and compliance

resource "google_bigquery_dataset" "audit_logs" {
  dataset_id                  = "keystone_${var.environment}_audit_logs"
  friendly_name               = "Audit Logs Dataset"
  description                 = "Dataset for storing infrastructure audit logs"
  location                    = var.region
  project                     = var.project_id
  
  delete_contents_on_destroy = var.environment != "prod"

  labels = {
    env = var.environment
  }
}

resource "google_logging_project_sink" "audit_sink" {
  name        = "keystone-${var.environment}-audit-sink"
  destination = "bigquery.googleapis.com/${google_bigquery_dataset.audit_logs.id}"
  project     = var.project_id

  # Filter for high-value audit signals: IAM changes, Secrets access, Data access
  filter = "protoPayload.methodName=(\"SetIamPolicy\" OR \"UpdateIAMPolicy\" OR \"google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion\") OR severity>=ERROR"

  unique_writer_identity = true
}

# Grant the sink's service identity permission to write to BigQuery
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_project_sink.audit_sink.writer_identity
}
