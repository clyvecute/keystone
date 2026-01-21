#!/bin/bash
set -euo pipefail

# Keystone Bootstrap Script
# Initializes the GCP environment for Terraform state management

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[BOOTSTRAP]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check dependencies
for cmd in gcloud terraform; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ENV="${1:-dev}"
BUCKET_NAME="keystone-tf-state-${PROJECT_ID}-${ENV}"

log "Starting bootstrap for environment: ${ENV} in project: ${PROJECT_ID}"

# 1. Enable Required APIs
log "Enabling critical APIs..."
gcloud services enable \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    cloudkms.googleapis.com \
    secretmanager.googleapis.com \
    vpcaccess.googleapis.com \
    binaryauthorization.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    --project="${PROJECT_ID}"

# 2. Create Terraform State Bucket
log "Creating state bucket: ${BUCKET_NAME}..."
if gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
    warn "Bucket already exists."
else
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --project="${PROJECT_ID}" \
        --location="${REGION}" \
        --uniform-bucket-level-access
    
    # Enable versioning for state recovery
    gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning
    success "State bucket created."
fi

# 3. Create .tfvars file if missing
TFVARS_PATH="terraform/environments/${ENV}/terraform.tfvars"
if [ ! -f "$TFVARS_PATH" ]; then
    log "Creating template tfvars..."
    cat > "$TFVARS_PATH" <<EOF
project_id = "${PROJECT_ID}"
region     = "${REGION}"
app_name   = "configra"
EOF
    success "Template tfvars created at ${TFVARS_PATH}"
fi

# 4. Initialize Terraform
log "Initializing terraform..."
cd "terraform/environments/${ENV}"
terraform init -backend-config="bucket=${BUCKET_NAME}"

success "Bootstrap complete! You can now run 'make plan ENV=${ENV}'"
