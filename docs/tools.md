# Tools

Keystone includes custom-built tools to enhance operational workflows.

## Preflight Checker

**Location:** `tools/preflight/`

**Purpose:** Validates environment readiness before deployment

**Language:** Go

**Why Go?**
- Fast compilation to single binary
- No runtime dependencies
- Cross-platform (Linux, macOS, Windows)
- Type-safe validation logic
- Demonstrates Go proficiency

### Features

- ✅ Checks gcloud CLI installation and authentication
- ✅ Verifies Terraform version compatibility
- ✅ Validates GCP project configuration
- ✅ Confirms required APIs are enabled
- ✅ Checks state bucket existence
- ✅ Validates Terraform formatting
- ✅ JSON output for CI/CD integration
- ✅ Clear pass/fail with actionable messages

### Usage

```bash
# Build
make build-preflight

# Run
make preflight

# Or directly
./bin/preflight

# With JSON output
PREFLIGHT_JSON=true ./bin/preflight
```

### Integration

**Makefile:**
```makefile
preflight: build-preflight
	@./bin/preflight
```

**GitHub Actions:**
```yaml
- name: Preflight Check
  run: make preflight
```

**Pre-deployment:**
```bash
make preflight && make apply ENV=prod
```

### Example Output

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

### Why This Matters

**For Recruiters:**
- Demonstrates Go proficiency
- Shows operational thinking
- Proves automation skills
- Real-world utility, not a toy

**For Operations:**
- Catches issues before deployment
- Saves time debugging
- Standardizes environment checks
- Integrates with CI/CD

**For Teams:**
- Onboarding tool for new developers
- Prevents common mistakes
- Documents requirements as code
- Self-documenting checks

---

## Future Tools (Planned)

### Config Validator
- Validates Terraform variables
- Checks for security misconfigurations
- Ensures cost controls are in place

### Drift Detector
- Detects infrastructure drift
- Compares actual vs. desired state
- Generates drift reports

### Cost Estimator
- Estimates deployment costs
- Compares cost across environments
- Alerts on cost increases

---

**See [tools/preflight/README.md](../tools/preflight/README.md) for detailed documentation.**
