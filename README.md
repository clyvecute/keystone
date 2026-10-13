# Keystone

Terraform infrastructure-as-code for running a containerized app on Google Cloud, with an automated CI pipeline for security scanning, container publishing, and cost analysis built into the repo.

I built it to learn how a production GCP setup fits together — Workload Identity Federation, zero-trust networking, encrypted secrets, and automated security checks. The infrastructure code is complete and ready to deploy; GCP billing is required to provision the live resources.

[![Build](https://github.com/clyvecute/keystone/actions/workflows/build.yml/badge.svg)](https://github.com/clyvecute/keystone/actions/workflows/build.yml)
[![Security Scan](https://github.com/clyvecute/keystone/actions/workflows/security-scan.yml/badge.svg)](https://github.com/clyvecute/keystone/actions/workflows/security-scan.yml)
[![Infrastructure Tests](https://github.com/clyvecute/keystone/actions/workflows/test.yml/badge.svg)](https://github.com/clyvecute/keystone/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](https://opensource.org/licenses/MIT)

Live status page: <https://clyvecute.github.io/keystone/>

---

## What is working right now

| Pipeline | Status | What it does |
|:---|:---|:---|
| **Build** | ✅ Live | Builds the Configra Docker image, pushes to `ghcr.io`, generates SBOM, runs Trivy vulnerability scan, uploads results to GitHub Security tab |
| **Security Scan** | ✅ Live | Runs `tfsec`, `Checkov`, `TruffleHog`, `Gitleaks`, and OpenSSF Scorecard on every push; results in the Security tab |
| **Infrastructure Tests** | ✅ Live | `terraform test` checks modules for configuration mistakes |
| **Workload Identity** | ✅ Configured | Keyless GCP authentication set up on `keystone-lab-123` — no service account keys stored |
| **Terraform modules** | ✅ Written | All IaC modules complete and tested |

The container image is published at `ghcr.io/clyvecute/configra` after every successful build.

---

## What it sets up (Terraform)

- **Compute:** Cloud Run service — 1 warm instance in prod, scales to 100, 80 concurrent requests per instance
- **Database:** Cloud SQL for PostgreSQL with regional HA, private IP only
- **Encryption and secrets:** Keys in Cloud KMS, runtime config in Secret Manager
- **Networking:** VPC connector so Cloud Run reaches the database without a public IP
- **Monitoring:** Dashboards and alerts defined in Terraform, audit logs in BigQuery for 12 months
- **Environments:** Separate dev and prod settings with remote state in GCS

---

## How the CI pipeline works

Three GitHub Actions workflows run on every push to `main`:

**Build** (`build.yml`)
- Checks out [`clyvecute/configra`](https://github.com/clyvecute/configra) source
- Builds and pushes the Docker image to GitHub Container Registry (`ghcr.io`)
- Generates an SBOM in SPDX format
- Runs Trivy and uploads vulnerability results to the GitHub Security tab

**Security Scan** (`security-scan.yml`)
- `tfsec` and `Checkov` scan all Terraform for misconfigurations
- `TruffleHog` and `Gitleaks` search the entire git history for leaked secrets
- `OpenSSF Scorecard` audits repo security practices
- All findings uploaded to the Security tab as SARIF

**Infrastructure Tests** (`test.yml`)
- `terraform test` validates module logic without deploying anything

**Keyless GCP auth.** When GCP deployment runs, GitHub Actions authenticates via Workload Identity Federation — no service account key JSON is ever stored or rotated.

---

## Preflight check

`tools/preflight` is a Go program that runs before Terraform applies. It checks GCP quotas, enabled APIs, IAM permissions, and the state bucket so a missing config fails in seconds rather than halfway through an apply.

---

## Cost estimate

| Environment | Estimated monthly cost |
|:---|:---|
| Production | ~$425/month |
| Dev | ~$25/month |

Estimates from Infracost. Most of the production cost is the regional HA Cloud SQL instance and the always-on Cloud Run minimum instance. These are not from a real bill.

---

## Design decisions

**Cloud Run, not Kubernetes.** This is a single service. GKE adds cluster overhead that isn't needed here.

**GCP only.** Staying on one provider means using its security primitives directly rather than a lowest-common-denominator abstraction layer.

**One region.** The database is HA within the region with backups to a second region. Multi-region would cost significantly more.

**No stored credentials.** Workload Identity Federation means no service account key to rotate, leak, or forget.

---

## Not done yet

- No load balancer is in front of Cloud Run, so Cloud Armor and global TLS are not active
- Nothing has been load tested — scaling numbers are configuration, not measured capacity
- The security scanners catch common issues but this is not a SOC 2 or ISO 27001 audit

---

## What broke while building it

**WSL vs Windows gcloud credentials.** Running `bash scripts/setup-wif.sh` launched WSL bash, which has its own separate gcloud config with no credentials. The fix was to write a native PowerShell version of the setup script (`scripts/setup-wif.ps1`) that runs in the same context as the authenticated Windows gcloud session.

**GCR requires billing, ghcr.io does not.** The original workflow pushed to `gcr.io`, which now routes through Artifact Registry — a paid API. Switched the build to publish to GitHub Container Registry (`ghcr.io`) instead, which is free and authenticates automatically with `GITHUB_TOKEN`.

**Docker cache export needs Buildx.** `cache-to: type=gha` fails with the default Docker driver. Added `docker/setup-buildx-action` to initialize a `docker-container` builder before the build step.

---

## Docs

- [Architecture](docs/architecture.md)
- [Deployment guide](docs/deployment.md)
- [Security](docs/security.md)
- [How things break](docs/how-things-break.md)
- [Cost analysis](docs/STANDOUT.md)

---

## License

MIT
