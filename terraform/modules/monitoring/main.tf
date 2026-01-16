# Monitoring Module
# Creates monitoring dashboards and alert policies

# GCS bucket for storing monitoring configs
resource "google_storage_bucket" "monitoring" {
  name          = "${var.app_name}-${var.environment}-monitoring"
  location      = var.region
  project       = var.project_id
  force_destroy = var.environment != "prod"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

# Uptime check for service availability
resource "google_monitoring_uptime_check_config" "service" {
  count        = var.service_url != "" ? 1 : 0
  display_name = "${var.app_name}-${var.environment}-uptime"
  timeout      = "10s"
  period       = "60s"
  project      = var.project_id

  http_check {
    path         = var.health_check_path
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = replace(var.service_url, "https://", "")
    }
  }
}

# Alert policy for high error rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "${var.app_name}-${var.environment}-high-error-rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Error rate above threshold"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert policy for high latency
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "${var.app_name}-${var.environment}-high-latency"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Request latency above threshold"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_threshold_ms

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.service_name"]
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert policy for uptime check failure
resource "google_monitoring_alert_policy" "uptime_failure" {
  count        = var.service_url != "" ? 1 : 0
  display_name = "${var.app_name}-${var.environment}-uptime-failure"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failed"

    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id=\"${google_monitoring_uptime_check_config.service[0].uptime_check_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "60s"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        group_by_fields      = ["resource.*"]
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}
