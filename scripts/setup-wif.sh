#!/bin/bash
# scripts/setup-wif.sh
# Automates the setup of Workload Identity Federation for Keystone

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[WIF-SETUP]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. Configuration
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    error "No GCP project configured. Run 'gcloud config set project [PROJECT_ID]'"
    exit 1
fi

# Get the repository name from git
if ! REPO_FULL=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:\/](.*)\.git/\1/'); then
    warn "Could not detect GitHub repository from git remote. Using placeholder."
    REPO_FULL="your-username/keystone"
fi

POOL_NAME="keystone-pool"
PROVIDER_NAME="keystone-github"
SA_NAME="keystone-github-actions"

log "Starting Workload Identity Federation setup for Project: ${PROJECT_ID}"
log "Target Repository: ${REPO_FULL}"

# 2. Enable Required APIs
log "Enabling IAM and Resource Manager APIs..."
gcloud services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project="${PROJECT_ID}"

# 3. Create Service Account
log "Creating Service Account: ${SA_NAME}..."
if gcloud iam service-accounts describe "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --project="${PROJECT_ID}" &>/dev/null; then
    warn "Service account already exists."
else
    gcloud iam service-accounts create "${SA_NAME}" \
        --display-name="Keystone GitHub Actions SA" \
        --project="${PROJECT_ID}"
    success "Service account created."
fi

# 4. Create Workload Identity Pool
log "Creating Workload Identity Pool: ${POOL_NAME}..."
if gcloud iam workload-identity-pools describe "${POOL_NAME}" --location="global" --project="${PROJECT_ID}" &>/dev/null; then
    warn "Workload identity pool already exists."
else
    gcloud iam workload-identity-pools create "${POOL_NAME}" \
        --location="global" \
        --display-name="Keystone Identity Pool" \
        --project="${PROJECT_ID}"
    success "Pool created."
fi

# 5. Get Pool Full ID
POOL_ID=$(gcloud iam workload-identity-pools describe "${POOL_NAME}" \
    --location="global" \
    --format='value(name)' \
    --project="${PROJECT_ID}")

# 6. Create Workload Identity Provider
log "Creating OIDC Provider: ${PROVIDER_NAME}..."
if gcloud iam workload-identity-pools providers describe "${PROVIDER_NAME}" \
    --location="global" \
    --workload-identity-pool="${POOL_NAME}" \
    --project="${PROJECT_ID}" &>/dev/null; then
    warn "Provider already exists."
else
    gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_NAME}" \
        --location="global" \
        --workload-identity-pool="${POOL_NAME}" \
        --display-name="Keystone GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --project="${PROJECT_ID}"
    success "Provider created."
fi

# 7. Bind Service Account to GitHub Repo
log "Binding Service Account to Repository: ${REPO_FULL}..."
gcloud iam service-accounts add-iam-policy-binding "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/${REPO_FULL}"

# 8. Grant Project-Level Permissions to SA
log "Granting permissions to Service Account..."
ROLES=(
    "roles/compute.networkAdmin"
    "roles/compute.securityAdmin"
    "roles/run.admin"
    "roles/binaryauthorization.policyEditor"
    "roles/cloudsql.admin"
    "roles/cloudkms.admin"
    "roles/storage.admin"
    "roles/monitoring.admin"
    "roles/logging.admin"
    "roles/secretmanager.admin"
    "roles/resourcemanager.projectIamAdmin"
    "roles/iam.serviceAccountUser"
)

for role in "${ROLES[@]}"; do
    log "Adding role: ${role}"
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="${role}" \
        --condition=None > /dev/null
done

# 9. Output Results
PROVIDER_ID=$(gcloud iam workload-identity-pools providers describe "${PROVIDER_NAME}" \
    --location="global" \
    --workload-identity-pool="${POOL_NAME}" \
    --format='value(name)' \
    --project="${PROJECT_ID}")

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  WORKLOAD IDENTITY FEDERATION SETUP COMPLETE!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\nAdd the following secrets to your GitHub repository:"
echo -e "Settings > Secrets and variables > Actions > New repository secret\n"
echo -e "  ${YELLOW}WIF_PROVIDER${NC}:          ${PROVIDER_ID}"
echo -e "  ${YELLOW}WIF_SERVICE_ACCOUNT${NC}:   ${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo -e "  ${YELLOW}GCP_PROJECT_ID${NC}:        ${PROJECT_ID}"
echo -e "\n${BLUE}Note:${NC} Ensure your repo is set to '${REPO_FULL}'."
echo -e "If it's different, update the IAM binding manually.\n"
