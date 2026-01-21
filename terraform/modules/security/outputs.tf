output "db_kms_key_id" {
  description = "KMS key ID for database encryption"
  value       = google_kms_crypto_key.db_key.id
}

output "storage_kms_key_id" {
  description = "KMS key ID for storage encryption"
  value       = google_kms_crypto_key.storage_key.id
}

output "keyring_id" {
  description = "KMS keyring ID"
  value       = google_kms_key_ring.keyring.id
}
