#!/bin/bash
set -euo pipefail

# Restore script for Keystone infrastructure
# Restores from backup created by backup.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_ID="${1:-}"
RESTORE_DIR="${RESTORE_DIR:-./restore}"
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

# Validate input
validate_input() {
    if [ -z "$BACKUP_ID" ]; then
        log_error "Usage: $0 <backup_id>"
        log_info "Example: $0 20240117_120000"
        log_info "Available backups:"
        gsutil ls "gs://${BACKUP_BUCKET}/${ENVIRONMENT}/" | grep backup- || true
        exit 1
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "GCP_PROJECT_ID not set"
        exit 1
    fi
}

# Confirm restore operation
confirm_restore() {
    log_warning "⚠️  WARNING: This will restore from backup ${BACKUP_ID}"
    log_warning "⚠️  Current data may be overwritten!"
    log_warning "⚠️  Environment: ${ENVIRONMENT}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
}

# Download backup from GCS
download_backup() {
    log_info "Downloading backup from GCS..."
    
    mkdir -p "$RESTORE_DIR"
    
    gsutil cp \
        "gs://${BACKUP_BUCKET}/${ENVIRONMENT}/backup-${BACKUP_ID}.tar.gz" \
        "$RESTORE_DIR/"
    
    log_success "Backup downloaded"
}

# Extract backup
extract_backup() {
    log_info "Extracting backup..."
    
    tar -xzf "$RESTORE_DIR/backup-${BACKUP_ID}.tar.gz" \
        -C "$RESTORE_DIR"
    
    log_success "Backup extracted to $RESTORE_DIR/$BACKUP_ID"
}

# Verify backup manifest
verify_manifest() {
    log_info "Verifying backup manifest..."
    
    if [ ! -f "$RESTORE_DIR/$BACKUP_ID/manifest.json" ]; then
        log_error "Manifest file not found"
        exit 1
    fi
    
    log_info "Backup manifest:"
    cat "$RESTORE_DIR/$BACKUP_ID/manifest.json"
    echo ""
    
    log_success "Manifest verified"
}

# Restore database
restore_database() {
    log_info "Restoring database..."
    
    local instance_name="configra-${ENVIRONMENT}-db"
    
    # List available backups for the instance
    log_info "Available database backups:"
    gcloud sql backups list \
        --instance="$instance_name" \
        --project="$PROJECT_ID" \
        --limit=10
    
    echo ""
    read -p "Enter the backup ID to restore (or 'skip' to skip): " -r backup_id
    
    if [[ $backup_id == "skip" ]]; then
        log_warning "Database restore skipped"
        return 0
    fi
    
    log_warning "Restoring database from backup: $backup_id"
    
    gcloud sql backups restore "$backup_id" \
        --backup-instance="$instance_name" \
        --backup-project="$PROJECT_ID" \
        --project="$PROJECT_ID"
    
    log_success "Database restored"
}

# Restore Terraform state
restore_terraform_state() {
    log_info "Restoring Terraform state..."
    
    local state_bucket="keystone-terraform-state-${ENVIRONMENT}"
    local state_prefix="terraform/state/${ENVIRONMENT}"
    
    if [ ! -d "$RESTORE_DIR/$BACKUP_ID/terraform_state" ]; then
        log_warning "No Terraform state found in backup"
        return 0
    fi
    
    log_warning "This will overwrite current Terraform state!"
    read -p "Continue? (yes/no): " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Terraform state restore skipped"
        return 0
    fi
    
    gsutil -m cp -r \
        "$RESTORE_DIR/$BACKUP_ID/terraform_state/*" \
        "gs://${state_bucket}/${state_prefix}/"
    
    log_success "Terraform state restored"
}

# Restore monitoring configurations
restore_monitoring() {
    log_info "Restoring monitoring configurations..."
    
    if [ ! -d "$RESTORE_DIR/$BACKUP_ID/monitoring" ]; then
        log_warning "No monitoring configurations found in backup"
        return 0
    fi
    
    log_info "Monitoring configurations found, but automatic restore not implemented"
    log_info "Please review and manually restore from:"
    log_info "  - $RESTORE_DIR/$BACKUP_ID/monitoring/alert_policies.json"
    log_info "  - $RESTORE_DIR/$BACKUP_ID/monitoring/uptime_checks.json"
}

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$RESTORE_DIR"
    log_success "Cleanup complete"
}

# Main execution
main() {
    log_info "Starting restore process"
    
    validate_input
    confirm_restore
    download_backup
    extract_backup
    verify_manifest
    restore_database
    restore_terraform_state
    restore_monitoring
    
    log_success "Restore completed successfully"
    log_info "Please verify all services are functioning correctly"
}

# Trap errors and cleanup
trap cleanup EXIT

# Run main function
main "$@"
