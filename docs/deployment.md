# Deployment Guide

## Prerequisites

### Required Tools
- **Terraform** >= 1.5.0
- **gcloud CLI** >= 400.0.0
- **Go** (for Preflight Checker)
- **Make**

### Required Access
- GCP project with billing enabled
- Owner or Editor role on the project
- GitHub repository for CI/CD

---

## Initial Setup (The Bootstrap)

Keystone provides a "Day-Zero" bootstrap script that handles the complex initial setup of APIs, state buckets, and security policies.

### 1. Configure Environment
```bash
# Clone and enter
git clone https://github.com/yourusername/keystone.git
cd keystone

# Initialize configuration
cp .env.example .env
# Edit .env and set GCP_PROJECT_ID, GCP_REGION, etc.
```

### 2. High-Speed Bootstrap
```bash
# This script enables required Google APIs (Cloud Run, Cloud SQL, KMS, etc.)
# and creates the versioned Terraform State Buckets.
make bootstrap ENV=dev
```

### 3. Verify Environment Readiness
```bash
# Run the Go preflight checker to validate APIs, credentials, and quotas
make preflight ENV=dev
```

---

## Infrastructure Deployment

### 1. Validate & Test
Before applying any changes, verify the security invariants and unit tests.
```bash
# Run terraform fmt and validate
make validate

# Run infrastructure unit tests (checks firewall rules, PGA, etc.)
make test-infra
```

### 2. Plan & Cost Review
```bash
# Generates a plan and shows the estimated monthly cost increase via Infracost
make plan ENV=dev
```

### 3. Apply
```bash
make apply ENV=dev
```

---

## Production Deployment

### 1. Production Bootstrap
Repeat the bootstrap for the production project context.
```bash
make bootstrap ENV=prod
```

### 2. Manual Verification
Production requires strict adherence to security policies.
```bash
# Preflight specifically for production
make preflight ENV=prod

# Run security scans (tfsec, checkov)
make security-scan
```

### 3. CI/CD Integration (GitHub Actions)
The recommended way to deploy to production is via the automated pipeline.
1. Configure **Workload Identity Federation** (see `docs/security.md`).
2. Add secrets to GitHub: `GCP_PROJECT_ID`, `WIF_PROVIDER`, `WIF_SERVICE_ACCOUNT`.
3. Push to `main`.

---

## Day-2 Operations

### Secret Rotation
Automated rotation of database passwords and service account keys:
```bash
make rotate-secrets
```

### Infrastructure Auditing
Verify the BigQuery audit log sink is receiving signals:
```bash
# Trigger an audit event (e.g., access a secret)
gcloud secrets versions access latest --secret="db-password"

# Run audit report
make security-audit
```

### System Backups
```bash
# Manually trigger a backup
make backup

# List available internal backups
gsutil ls gs://keystone-backups/
```

---

## Rollback Procedures

### Application Rollback
```bash
# Instantly shift traffic back to a known-stable revision
gcloud run services update-traffic configra-prod \
  --to-revisions=PREVIOUS_REVISION_ID=100 \
  --region=us-central1
```

### Infrastructure Rollback
```bash
# Revert the latest commit and apply
git revert HEAD
make apply ENV=prod
```

---

## Troubleshooting

- **KMS Key Not Found**: Ensure the initial `make apply` has completed; keys are provisioned during first apply.
- **VPC Connector Busy**: Wait 5 minutes for GCP to tear down internal routing before retrying.
- **State Lock**: If terraform crashes, use `terraform force-unlock <ID>` in the environment directory.
- **WIF Authentication Error**: If the GitHub Action fails with "must specify exactly one of workload_identity_provider or credentials_json", it means the `WIF_PROVIDER` secret is missing or empty. Run `make setup-wif` locally to generate the correct values and add them to GitHub Secrets.

---

## Appendix: Automated WIF Setup

Keystone includes a utility to handle the complex handshake between GCP and GitHub:

```bash
# 1. Ensure you are authenticated with gcloud
gcloud auth login

# 2. Run the setup utility
make setup-wif

# 3. Follow the output instructions to add WIF_PROVIDER and WIF_SERVICE_ACCOUNT to GitHub Secrets.
```

---

*This guide is part of the Keystone Operations Manual. Version: 2.1*
