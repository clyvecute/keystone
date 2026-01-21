# Compute Module
# Creates Cloud Run service for serverless deployment

resource "google_cloud_run_service" "app" {
  name     = "${var.app_name}-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    spec {
      containers {
        image = var.container_image

        ports {
          container_port = var.container_port
        }

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        env {
          name  = "APP_NAME"
          value = var.app_name
        }

        # Add more environment variables as needed
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
      }

      container_concurrency = var.container_concurrency
      timeout_seconds       = var.timeout_seconds
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"        = var.min_instances
        "autoscaling.knative.dev/maxScale"        = var.max_instances
        "run.googleapis.com/vpc-access-connector" = var.vpc_connector_id
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  lifecycle {
    ignore_changes = [
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
}

# IAM policy to allow public access (adjust for production)
resource "google_cloud_run_service_iam_member" "public_access" {
  count    = var.allow_public_access ? 1 : 0
  service  = google_cloud_run_service.app.name
  location = google_cloud_run_service.app.location
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Service account for Cloud Run
resource "google_service_account" "app" {
  account_id   = "${var.app_name}-${var.environment}-sa"
  display_name = "Service account for ${var.app_name} ${var.environment}"
  project      = var.project_id
}

# Grant minimal permissions to service account
resource "google_project_iam_member" "app_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "app_metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Secret Manager access to service account
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Binary Authorization policy for container image verification
resource "google_binary_authorization_policy" "policy" {
  count = var.enable_binary_authorization ? 1 : 0

  admission_whitelist_patterns {
    name_pattern = "gcr.io/${var.project_id}/*"
  }

  default_admission_rule {
    evaluation_mode  = var.environment == "prod" ? "REQUIRE_ATTESTATION" : "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    
    dynamic "require_attestations_by" {
      for_each = var.environment == "prod" ? [1] : []
      content {
        attestation_authority_note = var.attestation_authority_note
      }
    }
  }

  global_policy_evaluation_mode = "ENABLE"
}
