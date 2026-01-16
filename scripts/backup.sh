#!/bin/bash
set -euo pipefail

# Backup script for Keystone infrastructure
# Creates backups of database and critical configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-./backups}"
ENVIRONMENT="${APP_ENV:-dev}"
PROJECT_ID="${GCP_PROJECT_ID:-}"
BACKUP_BUCKET="${BACKUP_BUCKET:-keystone-backups}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "GCP_PROJECT_ID not set"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory..."
    mkdir -p "$BACKUP_DIR/$TIMESTAMP"
    log_success "Backup directory created: $BACKUP_DIR/$TIMESTAMP"
}

# Backup Cloud SQL database
backup_database() {
    log_info "Starting database backup..."
    
    local instance_name="configra-${ENVIRONMENT}-db"
    local backup_id="backup-${TIMESTAMP}"
    
    gcloud sql backups create \
        --instance="$instance_name" \
        --project="$PROJECT_ID" \
        --description="Automated backup ${TIMESTAMP}" \
        2>&1 | tee "$BACKUP_DIR/$TIMESTAMP/database_backup.log"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Database backup created: $backup_id"
    else
        log_error "Database backup failed"
        return 1
    fi
}

# Backup Terraform state
backup_terraform_state() {
    log_info "Backing up Terraform state..."
    
    local state_bucket="keystone-terraform-state-${ENVIRONMENT}"
    local state_prefix="terraform/state/${ENVIRONMENT}"
    
    gsutil -m cp -r \
        "gs://${state_bucket}/${state_prefix}/*" \
        "$BACKUP_DIR/$TIMESTAMP/terraform_state/" \
        2>&1 | tee "$BACKUP_DIR/$TIMESTAMP/terraform_backup.log"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Terraform state backed up"
    else
        log_warning "Terraform state backup failed (may not exist yet)"
    fi
}

# Backup monitoring configurations
backup_monitoring() {
    log_info "Backing up monitoring configurations..."
    
    mkdir -p "$BACKUP_DIR/$TIMESTAMP/monitoring"
    
    # Export alert policies
    gcloud alpha monitoring policies list \
        --project="$PROJECT_ID" \
        --format=json \
        > "$BACKUP_DIR/$TIMESTAMP/monitoring/alert_policies.json"
    
    # Export uptime checks
    gcloud monitoring uptime list \
        --project="$PROJECT_ID" \
        --format=json \
        > "$BACKUP_DIR/$TIMESTAMP/monitoring/uptime_checks.json"
    
    log_success "Monitoring configurations backed up"
}

# Create backup manifest
create_manifest() {
    log_info "Creating backup manifest..."
    
    cat > "$BACKUP_DIR/$TIMESTAMP/manifest.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "environment": "$ENVIRONMENT",
  "project_id": "$PROJECT_ID",
  "backup_type": "full",
  "components": [
    "database",
    "terraform_state",
    "monitoring"
  ],
  "created_by": "$(whoami)",
  "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_success "Manifest created"
}

# Upload to GCS
upload_to_gcs() {
    log_info "Uploading backup to GCS..."
    
    # Create tarball
    tar -czf "$BACKUP_DIR/backup-${TIMESTAMP}.tar.gz" \
        -C "$BACKUP_DIR" \
        "$TIMESTAMP"
    
    # Upload to GCS
    gsutil cp \
        "$BACKUP_DIR/backup-${TIMESTAMP}.tar.gz" \
        "gs://${BACKUP_BUCKET}/${ENVIRONMENT}/"
    
    log_success "Backup uploaded to gs://${BACKUP_BUCKET}/${ENVIRONMENT}/backup-${TIMESTAMP}.tar.gz"
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups..."
    
    local retention_days="${BACKUP_RETENTION_DAYS:-30}"
    
    # Cleanup local backups older than retention period
    find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +${retention_days} -delete
    
    # Cleanup GCS backups older than retention period
    gsutil -m rm -r \
        "gs://${BACKUP_BUCKET}/${ENVIRONMENT}/backup-$(date -d "${retention_days} days ago" +%Y%m%d)*.tar.gz" \
        2>/dev/null || true
    
    log_success "Old backups cleaned up (retention: ${retention_days} days)"
}

# Main execution
main() {
    log_info "Starting backup process for environment: $ENVIRONMENT"
    
    validate_prerequisites
    create_backup_dir
    backup_database
    backup_terraform_state
    backup_monitoring
    create_manifest
    upload_to_gcs
    cleanup_old_backups
    
    log_success "Backup completed successfully: backup-${TIMESTAMP}.tar.gz"
    log_info "Backup location: gs://${BACKUP_BUCKET}/${ENVIRONMENT}/backup-${TIMESTAMP}.tar.gz"
}

# Run main function
main "$@"
