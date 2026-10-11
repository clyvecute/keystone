# Keystone

Terraform for running one containerized app on Google Cloud, with security checks, cost estimates and recovery notes built into the repo.

I built it to learn how a production setup fits together on GCP, and to have a reusable base for my own projects. [Fill in: what app, if any, you have deployed with it, or say plainly that it is a template with no app on it yet.]

[![Live Demo](https://img.shields.io/badge/Live%20Demo-Portfolio%20Dashboard-6366f1?style=flat&logo=github)](https://clyvecute.github.io/keystone/)
[![Security Scan](https://github.com/clyvecute/keystone/actions/workflows/security-scan.yml/badge.svg)](https://github.com/clyvecute/keystone/actions/workflows/security-scan.yml)
[![Build](https://github.com/clyvecute/keystone/actions/workflows/build.yml/badge.svg)](https://github.com/clyvecute/keystone/actions/workflows/build.yml)
[![Infrastructure Tests](https://github.com/clyvecute/keystone/actions/workflows/test.yml/badge.svg)](https://github.com/clyvecute/keystone/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](https://opensource.org/licenses/MIT)

Live status page: <https://clyvecute.github.io/keystone/>

---

## What it sets up

- **Compute:** one Cloud Run service. Production keeps 1 instance warm and scales up to 100, with 80 concurrent requests per instance.
- **Database:** Cloud SQL for PostgreSQL with regional high availability, reachable only over a private IP.
- **Encryption and secrets:** keys managed in Cloud KMS, runtime config in Secret Manager.
- **Networking:** a VPC connector so Cloud Run reaches the database privately.
- **Monitoring:** dashboards and alerts defined in Terraform, audit logs sent to BigQuery for 12 months.
- **Environments:** reusable modules with separate dev and prod settings, and remote state in a GCS bucket.

[Fill in: confirm whether Cloud Armor and Binary Authorization are actually deployed. Cloud Armor needs a load balancer in front of the service, and the compute module does not create one. See "Not done yet" below.]

---

## How the pipelines work

Three GitHub Actions workflows run on the repo: `build.yml`, `test.yml` and `security-scan.yml`.

**Sign-in without stored keys.** GitHub Actions authenticates to GCP with Workload Identity Federation, so there is no service account key to leak.

**Security scans** run on every push to main:
- `tfsec` and `Checkov` check the Terraform.
- `Trivy` checks for known vulnerabilities.
- `TruffleHog` and `Gitleaks` search the git history for secrets.
- `OpenSSF Scorecard` audits the repo's practices.
- Results are uploaded to the GitHub Security tab.

**Cost estimates.** Infracost comments the cost change on pull requests that touch Terraform.

**Tests.** `terraform test` checks the modules for configuration mistakes.

---

## Preflight check

`tools/preflight` is a small Go program that runs before Terraform. It checks GCP quotas, enabled APIs, IAM permissions and the state bucket, so a missing API fails in seconds instead of halfway through an apply. The checks run one after another and call `gcloud` or Terraform, so it is not fast yet. [Fill in: how long it takes on your machine, if you have measured it.]

## Configra dev integration

The dev environment can deploy the Configra API from [`clyvecute/configra`](https://github.com/clyvecute/configra). Configure `GCP_PROJECT_ID`, `WIF_PROVIDER`, and `WIF_SERVICE_ACCOUNT` as GitHub Actions secrets and bootstrap the dev Terraform state bucket first. Run the Keystone **Build** workflow with a Configra branch, tag, or commit in `configra_ref`; it builds and scans that Configra revision, then the deploy workflow applies the matching immutable image to dev and checks `/health` and `/ready`. Keystone pushes to `main` build Configra `main` automatically.

The dev Cloud Run service uses private Cloud SQL connectivity. Database settings and credentials and the generated Configra API key are delivered to Cloud Run from Secret Manager; the API key is configured on the seeded default Configra project during startup. After deployment, `terraform output -raw service_url` gives the API base URL and `terraform output -raw configra_api_key_secret_id` gives the Secret Manager ID for client credentials. A Keystone-hosted service should call Configra server-side with `X-API-Key`, using its own Secret Manager binding for that API key. Do not expose the key to browser code. This integration does not deploy or alter production.

---

## Common commands

| Task | Command |
|:---|:---|
| Set up keyless auth | `make setup-wif` |
| Run the security checks locally | `make security-audit` |
| Rotate secrets | `make rotate-secrets` |
| Restore the database | `make restore ID=...` |
| Preview changes and cost | `make plan ENV=prod` |

---

## Cost

The production setup is estimated at about $425 per month and dev at about $25. These come from Infracost estimates, not from a real bill. [Fill in: the date of the estimate, or your actual bill if you have deployed it.] Most of the production cost is the regional HA database and the always-on Cloud Run instance.

---

## Choices I made

**Cloud Run, not Kubernetes.** This is meant for a single service. GKE adds cluster work I would not need here. [Fill in: your own reason or an experience, and drop the "40%" figure unless you can source it.]

**GCP only.** Staying on one provider lets me use its security features directly instead of a lowest-common-denominator layer.

**One region.** The database is highly available within a region, with backups in a second region. Going multi-region costs a lot more and I did not need it. [Fill in: the real backup setup.]

**Maintenance windows for migrations.** I accepted brief downtime during schema changes instead of building zero-downtime migrations.

---

## Not done yet

- The compute module deploys Cloud Run directly. There is no load balancer or CDN, so Cloud Armor and global TLS are not in front of it. Adding that is the next infrastructure step.
- Nothing has been load tested, so the scaling numbers above are settings, not measured capacity.
- This project has not been audited. The scanners find common problems, but the repo does not make anything SOC 2 or ISO 27001 compliant by itself.

[Fill in: anything you know is unfinished, such as the restore command or the runbooks.]

---

## What broke while building it

[Fill in: two or three real problems you hit and how you fixed them, for example a Workload Identity error, a permission you missed or a failed apply. This is the section that makes the README read as written by a person.]

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
