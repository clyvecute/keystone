# Keystone Quick Reference

## 🚀 Common Commands

### Infrastructure Management
```bash
make init ENV=dev          # Initialize Terraform
make plan ENV=dev          # Preview changes
make apply ENV=dev         # Apply changes
make destroy ENV=dev       # Destroy infrastructure
```

### Operations
```bash
make backup                # Create backup
make restore BACKUP_ID=... # Restore from backup
make health                # Health check
make logs ENV=dev          # View logs
```

### Development
```bash
make fmt                   # Format code
make validate              # Validate config
make test-scripts          # Test scripts
make security-scan         # Security scan
```

## 📂 Key Files

| File | Purpose |
|------|---------|
| `README.md` | Project overview |
| `SETUP.md` | Complete setup guide |
| `Makefile` | Command shortcuts |
| `.env.example` | Environment template |
| `docs/architecture.md` | System design |
| `docs/deployment.md` | Deployment guide |
| `docs/failure-scenarios.md` | Incident runbooks |

## 🏗️ Module Structure

```
terraform/modules/
├── network/      # VPC, subnets, firewall
├── compute/      # Cloud Run services
├── database/     # Cloud SQL PostgreSQL
└── monitoring/   # Alerts, uptime checks
```

## 🌍 Environments

| Environment | Purpose | Config |
|-------------|---------|--------|
| `dev` | Development | `terraform/environments/dev/` |
| `prod` | Production | `terraform/environments/prod/` |

## 🔧 Scripts

| Script | Purpose |
|--------|---------|
| `backup.sh` | Backup database, state, configs |
| `restore.sh` | Restore from backup |
| `healthcheck.sh` | Validate service health |
| `verify-setup.sh` | Check repository structure |

## 📊 Monitoring

- **Dashboards**: `monitoring/dashboards/service-overview.json`
- **Alerts**: `monitoring/alerts/alert-policies.md`
- **Logs**: Cloud Logging (GCP Console)
- **Metrics**: Cloud Monitoring (GCP Console)

## 🔐 Security

- **Secrets**: Use Secret Manager, never commit
- **IAM**: Minimal permissions, service accounts
- **Network**: VPC, firewall rules, private IPs
- **Encryption**: At rest (AES-256), in transit (TLS 1.2+)

## 🚨 Emergency Procedures

### Service Down
```bash
# Rollback to previous revision
gcloud run services update-traffic SERVICE_NAME \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=$GCP_REGION
```

### Database Issue
```bash
# Restore from backup
./scripts/restore.sh BACKUP_ID
```

### Check Logs
```bash
gcloud logging read "resource.type=cloud_run_revision" --limit 50
```

## 📞 Quick Links

- **GCP Console**: https://console.cloud.google.com
- **GitHub Actions**: `.github/workflows/`
- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

## 💡 Tips

1. **Always plan before apply**: `make plan` before `make apply`
2. **Test in dev first**: Validate changes in dev environment
3. **Backup before major changes**: `make backup`
4. **Monitor deployments**: Watch logs during deploys
5. **Document changes**: Update docs when changing infrastructure

## 🎯 Next Steps

1. Configure `.env` with your GCP project
2. Create state buckets
3. Deploy to dev: `make apply ENV=dev`
4. Run health check: `make health`
5. Create first backup: `make backup`
6. Review monitoring dashboard
7. Test restore procedure
8. Deploy to prod when ready

---

**For detailed information, see `SETUP.md` and `docs/` directory.**
