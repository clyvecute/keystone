# Failure Scenarios & Incident Response

## Overview

This document outlines common failure scenarios, their symptoms, root causes, and step-by-step recovery procedures. Use this as a runbook during incidents.

---

## Scenario 1: Service Completely Down

### Symptoms
- Health checks failing
- 502/503 errors
- No response from service URL
- Alert: "Service Unavailable"

### Possible Causes
1. Container image failed to start
2. Database connection failure
3. Resource exhaustion
4. Bad deployment

### Diagnosis

```bash
# Check service status
gcloud run services describe configra-prod --region=$GCP_REGION

# Check recent logs
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 50 \
  --format json

# Check container instances
gcloud run revisions list --service=configra-prod --region=$GCP_REGION
```

### Recovery Steps

**Option 1: Rollback to Previous Revision**
```bash
# List revisions
gcloud run revisions list --service=configra-prod --region=$GCP_REGION

# Rollback to last known good revision
gcloud run services update-traffic configra-prod \
  --to-revisions=configra-prod-00042-xyz=100 \
  --region=$GCP_REGION

# Verify
./scripts/healthcheck.sh https://your-service-url.run.app
```

**Option 2: Redeploy**
```bash
# Redeploy current configuration
cd terraform/environments/prod
terraform apply -auto-approve

# Monitor deployment
gcloud run services describe configra-prod --region=$GCP_REGION
```

**Option 3: Emergency Fallback**
```bash
# Deploy known-good container image
terraform apply \
  -var="container_image=gcr.io/$GCP_PROJECT_ID/configra:stable"
```

### Post-Incident
- Review deployment logs
- Update deployment checklist
- Add monitoring for specific failure
- Document root cause

---

## Scenario 2: High Error Rate (5xx)

### Symptoms
- Increased 5xx errors
- Alert: "High Error Rate"
- Some requests succeeding, others failing
- Intermittent failures

### Possible Causes
1. Database connection pool exhaustion
2. Memory leaks
3. Dependency failure
4. Resource limits hit

### Diagnosis

```bash
# Check error rate
gcloud logging read \
  "resource.type=cloud_run_revision AND httpRequest.status>=500" \
  --limit 100

# Check resource utilization
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/cpu/utilization"' \
  --interval-start-time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --interval-end-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Check database connections
gcloud sql operations list --instance=configra-prod-db
```

### Recovery Steps

**Step 1: Increase Resources**
```bash
# Edit terraform/environments/prod/main.tf
# Increase cpu_limit and memory_limit
cpu_limit    = "2000m"  # was 1000m
memory_limit = "2Gi"    # was 1Gi

# Apply changes
terraform apply
```

**Step 2: Scale Out**
```bash
# Increase max instances
# Edit terraform/environments/prod/main.tf
max_instances = "200"  # was 100

terraform apply
```

**Step 3: Restart Service**
```bash
# Force new revision deployment
gcloud run services update configra-prod \
  --region=$GCP_REGION \
  --update-env-vars=RESTART_TIMESTAMP=$(date +%s)
```

### Post-Incident
- Analyze error patterns
- Review application logs
- Optimize database queries
- Add load testing to CI/CD

---

## Scenario 3: Database Failure

### Symptoms
- Database connection errors
- Timeout errors
- Alert: "Database Connection Pool Near Limit"
- Application can't read/write data

### Possible Causes
1. Database instance down
2. Connection pool exhausted
3. Disk full
4. Network connectivity issue

### Diagnosis

```bash
# Check database status
gcloud sql instances describe configra-prod-db

# Check database operations
gcloud sql operations list --instance=configra-prod-db

# Check disk usage
gcloud sql instances describe configra-prod-db \
  --format="value(settings.dataDiskSizeGb,currentDiskSize)"

# Check connections
gcloud sql connect configra-prod-db --user=postgres
# Then run: SELECT count(*) FROM pg_stat_activity;
```

### Recovery Steps

**If Database is Down**:
```bash
# Restart database instance
gcloud sql instances restart configra-prod-db

# Wait for restart
gcloud sql instances describe configra-prod-db \
  --format="value(state)"

# Verify connectivity
gcloud sql connect configra-prod-db --user=configra_user
```

**If Disk Full**:
```bash
# Increase disk size
gcloud sql instances patch configra-prod-db \
  --disk-size=200

# Enable automatic storage increase
gcloud sql instances patch configra-prod-db \
  --storage-auto-increase
```

**If Connection Pool Exhausted**:
```bash
# Kill idle connections
gcloud sql connect configra-prod-db --user=postgres
# Then run:
# SELECT pg_terminate_backend(pid) 
# FROM pg_stat_activity 
# WHERE state = 'idle' AND state_change < now() - interval '5 minutes';

# Increase max connections (requires restart)
gcloud sql instances patch configra-prod-db \
  --database-flags=max_connections=200
```

**Emergency: Restore from Backup**:
```bash
# List backups
gcloud sql backups list --instance=configra-prod-db

# Restore from backup
./scripts/restore.sh 20240117_120000
```

### Post-Incident
- Review connection pooling configuration
- Implement connection retry logic
- Add database monitoring
- Schedule maintenance window

---

## Scenario 4: Deployment Failed

### Symptoms
- GitHub Actions workflow failed
- Terraform apply errors
- New revision not created
- Alert: "Deployment Failed"

### Possible Causes
1. Terraform state lock
2. Invalid configuration
3. Permission errors
4. Resource quota exceeded

### Diagnosis

```bash
# Check GitHub Actions logs
# (View in GitHub UI)

# Check Terraform state
cd terraform/environments/prod
terraform show

# Validate configuration
terraform validate

# Check for state lock
terraform force-unlock LOCK_ID  # if locked
```

### Recovery Steps

**If State Locked**:
```bash
cd terraform/environments/prod

# Check lock info
terraform force-unlock -help

# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

**If Configuration Invalid**:
```bash
# Validate locally
terraform validate

# Format code
terraform fmt -recursive

# Re-run plan
terraform plan
```

**If Permission Error**:
```bash
# Check service account permissions
gcloud projects get-iam-policy $GCP_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions@*"

# Add missing permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"
```

**If Quota Exceeded**:
```bash
# Check quotas
gcloud compute project-info describe --project=$GCP_PROJECT_ID

# Request quota increase
# (Use GCP Console)
```

### Post-Incident
- Review deployment process
- Add pre-deployment validation
- Improve error messages
- Update documentation

---

## Scenario 5: Data Loss / Corruption

### Symptoms
- Missing data
- Corrupted records
- Inconsistent state
- User reports of lost data

### Possible Causes
1. Application bug
2. Database corruption
3. Accidental deletion
4. Migration failure

### Diagnosis

```bash
# Check database logs
gcloud logging read \
  "resource.type=cloudsql_database AND severity>=ERROR" \
  --limit 100

# Check recent operations
gcloud sql operations list --instance=configra-prod-db

# Verify data integrity
gcloud sql connect configra-prod-db --user=configra_user
# Run integrity checks
```

### Recovery Steps

**Step 1: Stop Writes (if corruption ongoing)**
```bash
# Scale down to 0 instances temporarily
gcloud run services update configra-prod \
  --min-instances=0 \
  --max-instances=0 \
  --region=$GCP_REGION
```

**Step 2: Assess Damage**
```bash
# Export current state
gcloud sql export sql configra-prod-db \
  gs://keystone-backups/emergency/current-state.sql \
  --database=configra

# Analyze data
# Download and review
```

**Step 3: Restore from Backup**
```bash
# List available backups
gcloud sql backups list --instance=configra-prod-db

# Restore to point-in-time (if enabled)
gcloud sql backups restore BACKUP_ID \
  --backup-instance=configra-prod-db \
  --backup-project=$GCP_PROJECT_ID

# Or use restore script
./scripts/restore.sh 20240117_120000
```

**Step 4: Verify Restoration**
```bash
# Connect and verify
gcloud sql connect configra-prod-db --user=configra_user

# Run verification queries
# SELECT count(*) FROM critical_table;
```

**Step 5: Resume Service**
```bash
# Scale back up
gcloud run services update configra-prod \
  --min-instances=1 \
  --max-instances=100 \
  --region=$GCP_REGION

# Run health check
./scripts/healthcheck.sh https://your-service-url.run.app
```

### Post-Incident
- Root cause analysis
- Add data validation
- Improve backup frequency
- Test restore procedures
- Update runbook

---

## Scenario 6: Security Incident

### Symptoms
- Unauthorized access alerts
- Unusual traffic patterns
- Compromised credentials
- Alert: "Suspicious Activity Detected"

### Possible Causes
1. Leaked credentials
2. Vulnerability exploit
3. DDoS attack
4. Insider threat

### Immediate Actions

**Step 1: Isolate**
```bash
# Disable public access
cd terraform/environments/prod
# Edit main.tf: allow_public_access = false
terraform apply

# Or block at firewall level
gcloud compute firewall-rules create block-all \
  --action=DENY \
  --rules=all \
  --source-ranges=0.0.0.0/0 \
  --priority=100
```

**Step 2: Rotate Credentials**
```bash
# Rotate database password
gcloud sql users set-password configra_user \
  --instance=configra-prod-db \
  --password=$(openssl rand -base64 32)

# Rotate service account keys
gcloud iam service-accounts keys create new-key.json \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com

# Delete old keys
gcloud iam service-accounts keys list \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts keys delete OLD_KEY_ID \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com
```

**Step 3: Audit**
```bash
# Review audit logs
gcloud logging read \
  "protoPayload.@type=type.googleapis.com/google.cloud.audit.AuditLog" \
  --limit 1000 \
  --format json > audit.json

# Check IAM policy changes
gcloud logging read \
  "protoPayload.methodName=SetIamPolicy" \
  --limit 100
```

**Step 4: Investigate**
```bash
# Check access logs
gcloud logging read \
  "resource.type=cloud_run_revision AND httpRequest.remoteIp!=''" \
  --limit 1000

# Export for analysis
gcloud logging read \
  "timestamp>=\"2024-01-17T00:00:00Z\"" \
  --format json > incident-logs.json
```

### Recovery Steps

1. **Patch Vulnerability**: Deploy fix immediately
2. **Restore from Clean Backup**: If compromised
3. **Re-enable Access**: After verification
4. **Monitor Closely**: Watch for repeat attempts

### Post-Incident
- Full security audit
- Penetration testing
- Update security policies
- Incident report
- Team training

---

## General Incident Response Checklist

### During Incident
- [ ] Acknowledge alert
- [ ] Assess severity
- [ ] Notify team
- [ ] Begin diagnosis
- [ ] Document actions
- [ ] Implement fix
- [ ] Verify resolution
- [ ] Monitor for recurrence

### After Incident
- [ ] Write incident report
- [ ] Conduct postmortem
- [ ] Update runbooks
- [ ] Implement preventive measures
- [ ] Share learnings
- [ ] Update monitoring

---

## Emergency Contacts

- **On-Call Engineer**: [Pager/Phone]
- **Team Lead**: [Contact]
- **GCP Support**: [Support Case Link]
- **Security Team**: [Contact]

## Useful Commands Reference

```bash
# Quick service status
gcloud run services describe configra-prod --region=$GCP_REGION

# Quick logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Quick rollback
gcloud run services update-traffic configra-prod \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=$GCP_REGION

# Quick health check
./scripts/healthcheck.sh https://your-service-url.run.app

# Quick backup
./scripts/backup.sh

# Quick restore
./scripts/restore.sh BACKUP_ID
```
