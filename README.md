# Keystone

**The load-bearing layer beneath Configra.**

Keystone exists to prove one thing: **you know how production systems are built, deployed, observed, and recovered.**

This is not an app. This is not a demo. This is infrastructure that works.

---

## What Makes Keystone Different

**Most portfolios show you can deploy. Keystone shows you can operate.**

### 🚀 Go Preflight Checker
Custom-built Go utility that validates environment readiness before deployment. Catches issues before they become incidents. [See tools/preflight/](tools/preflight/)

### 💥 Failure-First Documentation  
Documents how things **break**, not just how they work. Real failure scenarios with recovery procedures. [See docs/how-things-break.md](docs/how-things-break.md)

### 💰 Cost Awareness
Detailed cost analysis ($25/month dev, $425/month prod) with ROI justification. Shows you think like someone who manages budgets. [See docs/cost-analysis.md](docs/cost-analysis.md)

### 🎯 Explicit Non-Goals
Clear scope boundaries. States what we intentionally don't do and why. Shows restraint and pragmatism. [See Non-Goals](#non-goals)

**→ [Read why these matter](docs/STANDOUT.md)**

---

## What This Is

Keystone is a production-ready infrastructure repository demonstrating:

- **Infrastructure as Code** with Terraform
- **CI/CD pipelines** with GitHub Actions
- **Monitoring and observability** with Prometheus-compatible metrics and Grafana
- **Operational scripts** for backup, restore, and health validation
- **Security best practices** with IAM roles and secret management
- **Failure recovery** procedures and runbooks

---

## Repository Structure

```
keystone/
├─ terraform/          # Infrastructure as Code
│  ├─ environments/    # Environment-specific configs
│  ├─ modules/         # Reusable infrastructure modules
│  ├─ backend.tf       # Remote state configuration
│  ├─ providers.tf     # Cloud provider setup
│  └─ variables.tf     # Global variables
│
├─ ci/                 # CI/CD pipelines
│  └─ github-actions/  # GitHub Actions workflows
│
├─ scripts/            # Operational automation
│  ├─ backup.sh        # Backup procedures
│  ├─ restore.sh       # Restore procedures
│  └─ healthcheck.sh   # Health validation
│
├─ monitoring/         # Observability
│  ├─ dashboards/      # Grafana dashboards
│  └─ alerts/          # Alert configurations
│
└─ docs/               # Documentation
   ├─ architecture.md  # System design
   ├─ deployment.md    # Deployment procedures
   └─ failure-scenarios.md  # Incident response
```

---

## Tech Stack

### Infrastructure & Cloud
- **Terraform** - Industry-standard IaC
- **GCP Cloud Run** - Serverless container platform (or AWS EC2 for traditional compute)
- **GCS/S3** - Object storage for state, backups, and artifacts

### CI/CD
- **GitHub Actions** - Universal, auditable, no vendor lock-in
- Pipeline stages: lint → test → build → deploy → health check

### Monitoring & Observability
- **Prometheus-compatible metrics** - From Configra endpoints
- **Grafana dashboards** - Visualization and alerting
- **Cloud-native logging** - Cloud Logging (GCP) or CloudWatch (AWS)

### Automation & Ops
- **Shell scripts** - Backup, restore, health validation
- **Makefile** - Single entry point for local operations

### Security
- **Environment variables only** - No secrets in repo
- **IAM roles** - Minimal permissions, explicit policies
- **Terraform remote state** - Locked and versioned

---

## Quick Start

### Prerequisites
- Terraform >= 1.5
- GCP account with billing enabled (or AWS)
- GitHub repository with Actions enabled
- `gcloud` CLI configured (or `aws` CLI)

### Local Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/keystone.git
cd keystone

# Copy environment template
cp .env.example .env

# Edit .env with your values
# Then source it
source .env

# Initialize Terraform
make init

# Plan infrastructure changes
make plan

# Apply infrastructure
make apply
```

### Deploy to Production

```bash
# Deploy via CI/CD (recommended)
git push origin main

# Or deploy manually
make deploy-prod
```

---

## Operations

### Backup
```bash
make backup
```

### Restore
```bash
make restore BACKUP_ID=<timestamp>
```

### Health Check
```bash
make health
```

### View Logs
```bash
make logs ENV=prod
```

---

## Monitoring

Access Grafana dashboards:
- **Dev**: `http://localhost:3000`
- **Prod**: `https://monitoring.yourdomain.com`

Default credentials are in your `.env` file.

---

## Documentation

- [Architecture](docs/architecture.md) - System design and component overview
- [Deployment](docs/deployment.md) - Step-by-step deployment guide
- [Failure Scenarios](docs/failure-scenarios.md) - Incident response runbooks

---

## Why This Exists

Keystone demonstrates **real-world readiness**:

1. **Terraform isolation** - Infrastructure is readable and maintainable
2. **Explicit CI logic** - Every pipeline stage is auditable
3. **Operational thinking** - Scripts show you understand day-2 operations
4. **Failure awareness** - Docs prove you understand recovery, not just deployment

This repository signals maturity, discipline, and production experience.

---

## Non-Goals

**Keystone intentionally does NOT solve everything. Here's what we don't do:**

### What We Don't Provide

❌ **Multi-Region Deployment**
- Why: Adds significant complexity and cost (3-5x)
- Alternative: Single-region with cross-region backups
- When to add: When uptime SLA requires it (99.99%+)

❌ **Kubernetes**
- Why: Overkill for most applications
- Alternative: Cloud Run (serverless, simpler, cheaper)
- When to add: When you need stateful workloads or custom networking

❌ **Service Mesh (Istio, Linkerd)**
- Why: Unnecessary complexity for single-service architecture
- Alternative: Cloud Run's built-in traffic management
- When to add: When you have 10+ microservices

❌ **Custom Monitoring Stack (Prometheus + Grafana)**
- Why: Cloud Monitoring is sufficient and integrated
- Alternative: Cloud Monitoring with Grafana dashboards (optional)
- When to add: When you need custom metrics or on-prem monitoring

❌ **CI/CD for Multiple Applications**
- Why: Keystone is infrastructure for Configra specifically
- Alternative: Adapt workflows for your application
- When to add: When you have multiple services to deploy

❌ **Development Environment Parity**
- Why: Dev is intentionally cheaper (scales to zero, smaller DB)
- Alternative: Staging environment for production-like testing
- When to add: When you need exact prod replication for testing

❌ **Advanced Networking (VPN, Interconnect)**
- Why: Not needed for cloud-native applications
- Alternative: Cloud Run's built-in networking
- When to add: When connecting to on-prem systems

❌ **Compliance Certifications (SOC2, HIPAA, PCI-DSS)**
- Why: Requires additional controls and audits
- Alternative: GCP provides compliant infrastructure
- When to add: When your business requires it

❌ **Multi-Cloud (AWS + GCP + Azure)**
- Why: Vendor lock-in is acceptable for simplicity
- Alternative: GCP-native services
- When to add: When business requires multi-cloud (rare)

❌ **Zero-Downtime Database Migrations**
- Why: Requires complex blue-green database setup
- Alternative: Maintenance windows for schema changes
- When to add: When you can't afford any downtime

### Why We're Explicit About This

1. **Scope Control** - Prevents feature creep
2. **Cost Awareness** - Each feature has a cost
3. **Complexity Management** - Simpler is better
4. **Honest Communication** - Set clear expectations
5. **Future Roadmap** - Know what to add when needed

### When to Extend Keystone

Add features when:
- ✅ Business requirements demand it
- ✅ Cost is justified by value
- ✅ Team has capacity to maintain it
- ✅ Simpler alternatives have been exhausted

Don't add features because:
- ❌ "It would be cool"
- ❌ "Other companies do it"
- ❌ "It's best practice" (without context)
- ❌ "We might need it someday"

**Keystone is intentionally focused. This is a feature, not a limitation.**

---

## License

MIT
