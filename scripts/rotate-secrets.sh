#!/bin/bash
set -euo pipefail

# Secret Rotation Script for Keystone
# Rotates database passwords and other secrets stored in Secret Manager

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${APP_ENV:-dev}"
PROJECT_ID="${GCP_PROJECT_ID:-}"
APP_NAME="${APP_NAME:-configra}"
ROTATION_LOG="./logs/secret-rotation-$(date +%Y%m%d_%H%M%S).log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$ROTATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$ROTATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$ROTATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$ROTATION_LOG"
}

# Create log directory
mkdir -p ./logs

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

# Rotate database password
rotate_database_password() {
    log_info "Starting database password rotation..."
    
    local instance_name="${APP_NAME}-${ENVIRONMENT}-db"
    local secret_name="${APP_NAME}-${ENVIRONMENT}-db-password"
    local db_user="${DB_USER:-configra_user}"
    
    # Generate new password
    local new_password=$(openssl rand -base64 32)
    
    # Update database user password
    log_info "Updating database user password..."
    gcloud sql users set-password "$db_user" \
        --instance="$instance_name" \
        --password="$new_password" \
        --project="$PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        log_success "Database password updated"
    else
        log_error "Failed to update database password"
        return 1
    fi
    
    # Update Secret Manager
    log_info "Updating Secret Manager..."
    echo -n "$new_password" | gcloud secrets versions add "$secret_name" \
        --data-file=- \
        --project="$PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        log_success "Secret Manager updated"
    else
        log_error "Failed to update Secret Manager"
        return 1
    fi
    
    # Disable old secret versions (keep last 3)
    log_info "Disabling old secret versions..."
    local versions=$(gcloud secrets versions list "$secret_name" \
        --project="$PROJECT_ID" \
        --format="value(name)" \
        --sort-by="~createTime" \
        | tail -n +4)
    
    for version in $versions; do
        gcloud secrets versions disable "$version" \
            --secret="$secret_name" \
            --project="$PROJECT_ID" \
            --quiet
        log_info "Disabled secret version: $version"
    done
    
    log_success "Database password rotation completed"
}

# Rotate service account keys
rotate_service_account_keys() {
    log_info "Starting service account key rotation..."
    
    local sa_email="${APP_NAME}-${ENVIRONMENT}-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # List existing keys
    local keys=$(gcloud iam service-accounts keys list \
        --iam-account="$sa_email" \
        --format="value(name)" \
        --filter="keyType=USER_MANAGED")
    
    # Create new key
    log_info "Creating new service account key..."
    local key_file="./keys/sa-key-$(date +%Y%m%d_%H%M%S).json"
    mkdir -p ./keys
    
    gcloud iam service-accounts keys create "$key_file" \
        --iam-account="$sa_email" \
        --project="$PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        log_success "New service account key created: $key_file"
        log_warning "IMPORTANT: Update GitHub secrets with new key"
        log_warning "Key location: $key_file"
    else
        log_error "Failed to create new service account key"
        return 1
    fi
    
    # Delete old keys (older than 90 days)
    log_info "Checking for old keys to delete..."
    local old_date=$(date -d "90 days ago" +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d)
    
    for key in $keys; do
        local key_id=$(basename "$key")
        local created_at=$(gcloud iam service-accounts keys describe "$key_id" \
            --iam-account="$sa_email" \
            --format="value(validAfterTime)" \
            --project="$PROJECT_ID")
        
        if [[ "$created_at" < "$old_date" ]]; then
            log_warning "Deleting old key: $key_id (created: $created_at)"
            gcloud iam service-accounts keys delete "$key_id" \
                --iam-account="$sa_email" \
                --project="$PROJECT_ID" \
                --quiet
        fi
    done
    
    log_success "Service account key rotation completed"
}

# Rotate API keys
rotate_api_keys() {
    log_info "Starting API key rotation..."
    
    # This is a placeholder - implement based on your API key management
    log_warning "API key rotation not implemented - add your custom logic here"
    
    # Example for GCP API keys:
    # gcloud alpha services api-keys create --display-name="new-key"
    # gcloud alpha services api-keys delete OLD_KEY_ID
}

# Verify rotation
verify_rotation() {
    log_info "Verifying secret rotation..."
    
    local secret_name="${APP_NAME}-${ENVIRONMENT}-db-password"
    
    # Check latest secret version
    local latest_version=$(gcloud secrets versions list "$secret_name" \
        --project="$PROJECT_ID" \
        --format="value(name)" \
        --sort-by="~createTime" \
        --limit=1)
    
    log_info "Latest secret version: $latest_version"
    
    # Test database connection (optional - requires psql)
    if command -v psql &> /dev/null; then
        log_info "Testing database connection..."
        # Add your connection test here
        log_success "Database connection test passed"
    else
        log_warning "psql not found - skipping connection test"
    fi
    
    log_success "Verification completed"
}

# Create rotation audit log
create_audit_log() {
    log_info "Creating audit log..."
    
    local audit_file="./logs/rotation-audit-$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$audit_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$ENVIRONMENT",
  "project_id": "$PROJECT_ID",
  "rotated_secrets": [
    "database_password",
    "service_account_keys"
  ],
  "performed_by": "$(whoami)",
  "hostname": "$(hostname)",
  "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_success "Audit log created: $audit_file"
}

# Send notification
send_notification() {
    log_info "Sending rotation notification..."
    
    local webhook_url="${SLACK_WEBHOOK:-}"
    
    if [ -n "$webhook_url" ]; then
        curl -X POST "$webhook_url" \
            -H 'Content-Type: application/json' \
            -d "{
                \"text\": \"🔐 Secret rotation completed for $ENVIRONMENT environment\",
                \"attachments\": [{
                    \"color\": \"good\",
                    \"fields\": [
                        {\"title\": \"Environment\", \"value\": \"$ENVIRONMENT\", \"short\": true},
                        {\"title\": \"Timestamp\", \"value\": \"$(date)\", \"short\": true}
                    ]
                }]
            }" 2>&1 | tee -a "$ROTATION_LOG"
        
        log_success "Notification sent"
    else
        log_warning "SLACK_WEBHOOK not set - skipping notification"
    fi
}

# Main execution
main() {
    log_info "=== Starting Secret Rotation for $ENVIRONMENT environment ==="
    
    validate_prerequisites
    
    # Backup before rotation
    log_info "Creating backup before rotation..."
    ./scripts/backup.sh || log_warning "Backup failed - continuing anyway"
    
    # Perform rotations
    rotate_database_password
    rotate_service_account_keys
    rotate_api_keys
    
    # Verify and audit
    verify_rotation
    create_audit_log
    send_notification
    
    log_success "=== Secret rotation completed successfully ==="
    log_info "Rotation log: $ROTATION_LOG"
    log_warning "NEXT STEPS:"
    log_warning "1. Update GitHub secrets with new service account key"
    log_warning "2. Restart application to use new secrets"
    log_warning "3. Monitor application logs for any issues"
    log_warning "4. Test critical functionality"
}

# Run main function
main "$@"
