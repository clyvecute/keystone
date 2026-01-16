# Deployment Guide

## Prerequisites

### Required Tools
- **Terraform** >= 1.5.0
- **gcloud CLI** >= 400.0.0
- **Git** >= 2.30
- **Make** (optional, for convenience)

### Required Access
- GCP project with billing enabled
- Owner or Editor role on the project
- GitHub repository with Actions enabled

### Required Secrets
- `GCP_PROJECT_ID`: Your GCP project ID
- `WIF_PROVIDER`: Workload Identity Federation provider
- `WIF_SERVICE_ACCOUNT`: Service account for GitHub Actions
- `SLACK_WEBHOOK`: (Optional) Slack webhook for notifications

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/keystone.git
cd keystone
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
# Required variables:
# - GCP_PROJECT_ID
# - GCP_REGION
# - APP_NAME

# Source environment
source .env
```

### 3. Authenticate to GCP

```bash
# Login to GCP
gcloud auth login

# Set project
gcloud config set project $GCP_PROJECT_ID

# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  storage-api.googleapis.com \
  secretmanager.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com
```

### 4. Create State Bucket

```bash
# Create bucket for Terraform state
gsutil mb -p $GCP_PROJECT_ID \
  -c STANDARD \
  -l $GCP_REGION \
  gs://keystone-terraform-state-dev

# Enable versioning
gsutil versioning set on gs://keystone-terraform-state-dev

# Create backup bucket
gsutil mb -p $GCP_PROJECT_ID \
  -c STANDARD \
  -l $GCP_REGION \
  gs://keystone-backups
```

### 5. Configure Terraform Backend

Edit `terraform/environments/dev/main.tf` and uncomment the backend configuration:

```hcl
terraform {
  backend "gcs" {
    bucket = "keystone-terraform-state-dev"
    prefix = "terraform/state/dev"
  }
}
```

## Development Deployment

### Using Make (Recommended)

```bash
# Initialize Terraform
make init ENV=dev

# Plan changes
make plan ENV=dev

# Apply changes
make apply ENV=dev

# Get service URL
cd terraform/environments/dev
terraform output service_url
```

### Manual Deployment

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Plan deployment
terraform plan \
  -var="project_id=$GCP_PROJECT_ID" \
  -var="container_image=gcr.io/cloudrun/hello"

# Apply deployment
terraform apply \
  -var="project_id=$GCP_PROJECT_ID" \
  -var="container_image=gcr.io/cloudrun/hello"

# Get outputs
terraform output
```

## Production Deployment

### Prerequisites

1. **Create Production State Bucket**

```bash
gsutil mb -p $GCP_PROJECT_ID \
  -c STANDARD \
  -l $GCP_REGION \
  gs://keystone-terraform-state-prod

gsutil versioning set on gs://keystone-terraform-state-prod
```

2. **Configure Production Variables**

Create `terraform/environments/prod/terraform.tfvars`:

```hcl
project_id     = "your-project-id"
region         = "us-central1"
container_image = "gcr.io/your-project/configra:v1.0.0"
allow_public_access = true
ssh_source_ranges = ["YOUR_IP/32"]  # Restrict SSH
notification_channels = ["projects/your-project/notificationChannels/123"]
```

### Deployment Steps

```bash
# Initialize production
make init ENV=prod

# Review plan carefully
make plan ENV=prod

# Apply (requires confirmation)
make apply ENV=prod

# Run health check
SERVICE_URL=$(cd terraform/environments/prod && terraform output -raw service_url)
./scripts/healthcheck.sh $SERVICE_URL

# Create initial backup
./scripts/backup.sh
```

## CI/CD Deployment

### Setup GitHub Actions

1. **Configure Workload Identity Federation**

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# Grant permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Create workload identity pool
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions"

# Create provider
gcloud iam workload-identity-pools providers create-oidc github \
  --location="global" \
  --workload-identity-pool="github" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# Bind service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/yourusername/keystone"
```

2. **Configure GitHub Secrets**

In your GitHub repository, add these secrets:
- `GCP_PROJECT_ID`
- `WIF_PROVIDER`
- `WIF_SERVICE_ACCOUNT`
- `SLACK_WEBHOOK` (optional)

3. **Deploy via GitHub Actions**

```bash
# Push to main branch triggers deployment to dev
git push origin main

# Manual production deployment
# Go to Actions > Deploy > Run workflow > Select 'prod'
```

## Verification

### Check Service Health

```bash
# Get service URL
SERVICE_URL=$(cd terraform/environments/dev && terraform output -raw service_url)

# Run health check
./scripts/healthcheck.sh $SERVICE_URL
```

### Check Logs

```bash
# View recent logs
make logs ENV=dev

# Or use gcloud directly
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=configra-dev" \
  --limit 50 \
  --format json
```

### Check Monitoring

```bash
# View metrics in Cloud Console
gcloud monitoring dashboards list

# Or access Grafana (if configured)
open http://localhost:3000
```

## Rollback Procedure

### Rollback Cloud Run Deployment

```bash
# List revisions
gcloud run revisions list \
  --service=configra-dev \
  --region=$GCP_REGION

# Rollback to previous revision
gcloud run services update-traffic configra-dev \
  --to-revisions=configra-dev-00002-abc=100 \
  --region=$GCP_REGION
```

### Rollback Terraform Changes

```bash
# Revert to previous commit
git revert HEAD

# Apply previous state
make apply ENV=dev
```

### Restore from Backup

```bash
# List available backups
gsutil ls gs://keystone-backups/dev/

# Restore from backup
./scripts/restore.sh 20240117_120000
```

## Troubleshooting

### Terraform Errors

**State Lock Error**:
```bash
# Force unlock (use with caution)
cd terraform/environments/dev
terraform force-unlock LOCK_ID
```

**Provider Authentication Error**:
```bash
# Re-authenticate
gcloud auth application-default login
```

### Deployment Failures

**Container Image Not Found**:
```bash
# Verify image exists
gcloud container images list --repository=gcr.io/$GCP_PROJECT_ID

# Use default image for testing
terraform apply -var="container_image=gcr.io/cloudrun/hello"
```

**Database Connection Error**:
```bash
# Check database status
gcloud sql instances describe configra-dev-db

# Check firewall rules
gcloud compute firewall-rules list
```

### Health Check Failures

```bash
# Check service logs
gcloud logging read \
  "resource.type=cloud_run_revision" \
  --limit 100

# Check service status
gcloud run services describe configra-dev \
  --region=$GCP_REGION
```

## Maintenance

### Update Dependencies

```bash
# Update Terraform providers
terraform init -upgrade

# Update container image
terraform apply -var="container_image=gcr.io/$GCP_PROJECT_ID/configra:v2.0.0"
```

### Scale Resources

```bash
# Update max instances
# Edit terraform/environments/prod/main.tf
# Change max_instances value
terraform apply
```

### Rotate Secrets

```bash
# Generate new database password
gcloud sql users set-password configra_user \
  --instance=configra-prod-db \
  --password=$(openssl rand -base64 32)
```

## Best Practices

1. **Always plan before apply**: Review changes carefully
2. **Use version control**: Commit infrastructure changes
3. **Test in dev first**: Validate changes before production
4. **Monitor deployments**: Watch logs and metrics
5. **Backup before major changes**: Create backup before risky operations
6. **Document changes**: Update docs when infrastructure changes
7. **Use CI/CD for production**: Avoid manual production deployments
