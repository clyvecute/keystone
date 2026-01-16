# Preflight - Environment Readiness Validator

A lightweight Go utility that validates your environment is ready for Keystone deployment.

## What It Checks

### Required Checks (Must Pass)
- ✅ gcloud CLI installed
- ✅ gcloud authenticated
- ✅ Terraform installed
- ✅ Terraform version >= 1.5.0
- ✅ GCP_PROJECT_ID environment variable set
- ✅ Required GCP APIs enabled
- ✅ Terraform state bucket exists

### Optional Checks (Warnings Only)
- ⚠️ Backup bucket exists
- ⚠️ .env file configured
- ⚠️ Terraform files formatted

## Installation

```bash
# Build the binary
cd tools/preflight
go build -o ../../bin/preflight

# Or use the Makefile
make build-preflight
```

## Usage

### Basic Check
```bash
./bin/preflight
```

### With JSON Output
```bash
PREFLIGHT_JSON=true ./bin/preflight
```

### In CI/CD
```bash
# Add to GitHub Actions workflow
- name: Preflight Check
  run: |
    cd tools/preflight
    go run main.go
```

## Example Output

```
🚀 Keystone Preflight Check
Environment: dev
Timestamp: 2024-01-17T03:44:43Z

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Preflight Check Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ gcloud CLI is installed
✓ gcloud is authenticated
  → Active account: user@example.com
✓ Terraform is installed
✓ Terraform version is compatible
  → Version: 1.5.7
✓ GCP_PROJECT_ID is set
  → Project: my-project-id
✓ Required APIs are enabled
✓ Terraform state bucket exists
  → Bucket: gs://keystone-terraform-state-dev
⚠ Backup bucket does not exist
  → Create with: gsutil mb gs://keystone-backups
✓ .env file exists
✓ Terraform files are formatted
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: 10 | Passed: 9 | Failed: 0 | Warnings: 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Ready to deploy
```

## Exit Codes

- `0` - All required checks passed
- `1` - One or more required checks failed

## Why Go?

- **Fast**: Compiles to a single binary, runs instantly
- **Portable**: Works on Linux, macOS, Windows
- **No Dependencies**: Uses only Go standard library
- **Type-Safe**: Catches errors at compile time
- **Maintainable**: Clear, readable code

## Integration

### Makefile
```makefile
preflight: ## Run preflight checks
	@./bin/preflight
```

### GitHub Actions
```yaml
- name: Preflight Check
  run: make preflight
```

### Pre-commit Hook
```bash
#!/bin/bash
./bin/preflight || exit 1
```
