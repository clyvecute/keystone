# Security Module
# Handles KMS keys and project-wide security settings

resource "google_kms_key_ring" "keyring" {
  name     = "${var.app_name}-${var.environment}-keyring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "db_key" {
  name     = "${var.app_name}-${var.environment}-db-key"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "storage_key" {
  name     = "${var.app_name}-${var.environment}-storage-key"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# Grant Cloud SQL service account permission to use the key
resource "google_project_service_identity" "sql_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "sqladmin.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "sql_kms" {
  crypto_key_id = google_kms_crypto_key.db_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.sql_sa.email}"
}

# Grant GCS service account permission to use the key
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_kms" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Project-wide audit logging
resource "google_project_iam_audit_config" "project_audit" {
  project = var.project_id
  service = "allServices"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
