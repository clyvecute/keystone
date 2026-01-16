# How Things Break

**Most documentation tells you how things work. This tells you how they break.**

This is a living document of failure modes, their symptoms, and recovery procedures. Every incident teaches us something new.

---

## Philosophy

> "Hope is not a strategy. Plan for failure."

In production systems:
- **Everything fails eventually**
- **Failures cascade**
- **Time matters**
- **Documentation saves hours**

This document exists so that at 3 AM, when something breaks, you have a playbook.

---

## Table of Contents

1. [Deployment Failures](#deployment-failures)
2. [Runtime Failures](#runtime-failures)
3. [Data Failures](#data-failures)
4. [Infrastructure Failures](#infrastructure-failures)
5. [Configuration Failures](#configuration-failures)
6. [Dependency Failures](#dependency-failures)

---

## Deployment Failures

### Scenario: Terraform Apply Fails Mid-Execution

**What Happens:**
- Terraform state becomes inconsistent
- Some resources created, others not
- Subsequent applies fail with "already exists" errors
- Team is blocked from deploying

**Symptoms:**
```
Error: Error creating CloudRun service: googleapi: Error 409: Already Exists
```

**Root Causes:**
1. Network timeout during apply
2. Permission denied mid-execution
3. Resource quota exceeded
4. Concurrent applies (state lock failed)

**Immediate Actions:**
```bash
# 1. Check Terraform state
cd terraform/environments/prod
terraform show

# 2. Check for state lock
terraform force-unlock LOCK_ID  # Only if you're sure

# 3. Import existing resources
terraform import google_cloud_run_service.app projects/PROJECT/locations/REGION/services/SERVICE

# 4. Refresh state
terraform refresh
```

**Recovery:**
```bash
# Option 1: Import and continue
terraform import [resource_type].[name] [resource_id]
terraform apply

# Option 2: Destroy partial resources and retry
terraform destroy -target=google_cloud_run_service.app
terraform apply

# Option 3: Manual cleanup
gcloud run services delete SERVICE_NAME --region=REGION
terraform apply
```

**Prevention:**
- Use remote state with locking
- Set appropriate timeouts
- Use `-lock-timeout` flag
- Never run concurrent applies
- Always plan before apply

**Time to Recover:** 15-30 minutes

---

### Scenario: Container Image Build Fails in CI

**What Happens:**
- GitHub Actions workflow fails
- No new image pushed to GCR
- Deployment cannot proceed
- Team cannot ship features

**Symptoms:**
```
Error: failed to solve: failed to fetch oauth token
Error: Cannot connect to Docker daemon
```

**Root Causes:**
1. Docker daemon not available
2. Authentication expired
3. Dockerfile syntax error
4. Base image unavailable
5. Network issues

**Immediate Actions:**
```bash
# 1. Check GitHub Actions logs
# (View in GitHub UI)

# 2. Test build locally
docker build -t test .

# 3. Check authentication
gcloud auth configure-docker

# 4. Verify Dockerfile
docker build --no-cache -t test .
```

**Recovery:**
```bash
# Option 1: Retry workflow
# (Re-run in GitHub UI)

# Option 2: Build and push manually
docker build -t gcr.io/PROJECT/configra:manual .
docker push gcr.io/PROJECT/configra:manual

# Option 3: Use previous image
terraform apply -var="container_image=gcr.io/PROJECT/configra:v1.2.3"
```

**Prevention:**
- Pin base image versions
- Use multi-stage builds
- Cache Docker layers
- Test Dockerfile changes locally
- Monitor Docker Hub rate limits

**Time to Recover:** 10-20 minutes

---

### Scenario: Health Check Fails After Deployment

**What Happens:**
- New revision deployed successfully
- Health checks fail
- Traffic not shifted to new revision
- Old revision continues serving (good!)
- Deployment marked as failed

**Symptoms:**
```
Error: Health check failed
HTTP 503 Service Unavailable
Container failed to start
```

**Root Causes:**
1. Application crashes on startup
2. Database connection fails
3. Missing environment variables
4. Port mismatch (app vs container config)
5. Startup timeout too short

**Immediate Actions:**
```bash
# 1. Check new revision logs
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.revision_name=SERVICE-00123" \
  --limit 100

# 2. Check revision status
gcloud run revisions describe SERVICE-00123 --region=REGION

# 3. Test health endpoint
curl https://SERVICE-00123-abc.run.app/health
```

**Recovery:**
```bash
# Option 1: Rollback (automatic if traffic not shifted)
# No action needed - old revision still serving

# Option 2: Fix and redeploy
# Fix issue, commit, push

# Option 3: Manual rollback if needed
gcloud run services update-traffic SERVICE \
  --to-revisions=SERVICE-00122=100 \
  --region=REGION
```

**Prevention:**
- Test health endpoint locally
- Increase startup timeout
- Add readiness probes
- Validate env vars in CI
- Test database connectivity

**Time to Recover:** 5-15 minutes (if rollback) or 30-60 minutes (if fix needed)

---

## Runtime Failures

### Scenario: Sudden Traffic Spike Causes 503s

**What Happens:**
- Traffic increases 10x unexpectedly
- Cloud Run hits max instances
- New requests get 503 errors
- Users see "Service Unavailable"
- Alerts firing

**Symptoms:**
```
HTTP 503 Service Unavailable
Error: Container instance limit reached
Alert: High Error Rate (>5%)
```

**Root Causes:**
1. Max instances set too low
2. Container startup too slow
3. Cold start latency
4. Actual attack/bot traffic
5. Viral content/HN front page

**Immediate Actions:**
```bash
# 1. Check current instance count
gcloud run services describe SERVICE --region=REGION \
  --format="value(status.traffic[0].latestRevision)"

# 2. Increase max instances immediately
gcloud run services update SERVICE \
  --max-instances=500 \
  --region=REGION

# 3. Check if it's legitimate traffic
gcloud logging read \
  "resource.type=cloud_run_revision AND httpRequest.userAgent!=''" \
  --limit 1000 | grep userAgent
```

**Recovery:**
```bash
# Quick fix: Increase limits
gcloud run services update SERVICE \
  --max-instances=1000 \
  --min-instances=10 \
  --region=REGION

# Or via Terraform (slower)
# Edit terraform/environments/prod/main.tf
max_instances = "1000"
min_instances = "10"
terraform apply
```

**Prevention:**
- Set appropriate max instances
- Use min instances for prod
- Implement rate limiting
- Add Cloud CDN for static content
- Monitor traffic patterns
- Set up auto-scaling alerts

**Time to Recover:** 2-5 minutes (manual) or 10-15 minutes (Terraform)

---

### Scenario: Memory Leak Causes OOM Kills

**What Happens:**
- Container memory usage grows over time
- Eventually hits memory limit
- Container killed and restarted
- Requests fail during restart
- Cycle repeats

**Symptoms:**
```
Error: Container killed (OOMKilled)
Exit code: 137
Memory usage: 512Mi/512Mi (100%)
Frequent container restarts
```

**Root Causes:**
1. Application memory leak
2. Memory limit too low
3. Connection pool not closed
4. Large response buffering
5. Caching without limits

**Immediate Actions:**
```bash
# 1. Check memory usage
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/memory/utilization"'

# 2. Increase memory limit temporarily
gcloud run services update SERVICE \
  --memory=2Gi \
  --region=REGION

# 3. Check for memory leaks in logs
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 100
```

**Recovery:**
```bash
# Short-term: Increase memory
gcloud run services update SERVICE \
  --memory=2Gi \
  --cpu=2 \
  --region=REGION

# Long-term: Fix the leak
# - Profile application
# - Fix memory leak
# - Deploy fix
# - Reduce memory back to normal
```

**Prevention:**
- Profile memory usage
- Set connection pool limits
- Implement response streaming
- Add memory usage monitoring
- Use memory profiling tools
- Regular load testing

**Time to Recover:** 5 minutes (increase memory) + hours/days (fix leak)

---

## Data Failures

### Scenario: Database Becomes Read-Only

**What Happens:**
- Disk full on database instance
- Database switches to read-only mode
- All writes fail
- Application errors on POST/PUT/DELETE
- Users cannot save data

**Symptoms:**
```
Error: database is in read-only mode
Error: no space left on device
Alert: Database Disk Usage >95%
```

**Root Causes:**
1. Disk full (most common)
2. Too many connections
3. Replication lag
4. Maintenance mode
5. Corruption recovery

**Immediate Actions:**
```bash
# 1. Check disk usage
gcloud sql instances describe DB_INSTANCE \
  --format="value(settings.dataDiskSizeGb,currentDiskSize)"

# 2. Increase disk size immediately
gcloud sql instances patch DB_INSTANCE \
  --disk-size=200

# 3. Check for large tables
gcloud sql connect DB_INSTANCE --user=postgres
# Then: SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;
```

**Recovery:**
```bash
# Quick fix: Increase disk
gcloud sql instances patch DB_INSTANCE \
  --disk-size=200 \
  --storage-auto-increase

# Clean up if needed
# - Delete old logs
# - Archive old data
# - Vacuum database
```

**Prevention:**
- Enable auto-increase storage
- Monitor disk usage
- Set disk usage alerts (<80%)
- Regular data archival
- Vacuum regularly
- Plan capacity

**Time to Recover:** 5-10 minutes (disk increase) + 30-60 minutes (cleanup)

---

### Scenario: Bad Migration Corrupts Data

**What Happens:**
- Migration runs in production
- Data transformed incorrectly
- Application reads bad data
- Users see wrong information
- Panic ensues

**Symptoms:**
```
Error: Invalid data format
Users reporting incorrect values
Data inconsistencies
Foreign key violations
```

**Root Causes:**
1. Migration not tested
2. Logic error in migration
3. Race condition during migration
4. Partial migration failure
5. Wrong environment

**Immediate Actions:**
```bash
# 1. STOP THE MIGRATION if still running
# Kill the migration process

# 2. Assess damage
gcloud sql connect DB_INSTANCE --user=postgres
# Check affected rows

# 3. Restore from backup if severe
./scripts/restore.sh BACKUP_ID
```

**Recovery:**
```bash
# Option 1: Rollback migration (if possible)
# Run reverse migration

# Option 2: Restore from backup
# List backups
gcloud sql backups list --instance=DB_INSTANCE

# Restore
gcloud sql backups restore BACKUP_ID \
  --backup-instance=DB_INSTANCE

# Option 3: Manual data fix
# Write corrective SQL
# Test on dev first
# Apply to prod
```

**Prevention:**
- **Always test migrations on dev first**
- Use transactions
- Create backup before migration
- Have rollback plan
- Test with production-like data
- Use migration tools with dry-run
- Peer review migrations

**Time to Recover:** 1-4 hours (depending on data size and backup restore time)

**Cost:** High - potential data loss, user trust

---

## Infrastructure Failures

### Scenario: GCP Region Outage

**What Happens:**
- Entire GCP region goes down
- All services in that region unavailable
- Database unreachable
- Complete service outage
- No ETA from GCP

**Symptoms:**
```
Error: Service Unavailable
Error: Connection timeout
All health checks failing
GCP Status Dashboard shows outage
```

**Root Causes:**
1. GCP infrastructure failure
2. Network partition
3. Power outage at datacenter
4. Natural disaster

**Immediate Actions:**
```bash
# 1. Confirm it's a GCP issue
# Check: https://status.cloud.google.com

# 2. Communicate to users
# Post status page update

# 3. If multi-region setup exists
# Failover to backup region

# 4. If single region
# Wait for GCP to restore
# Monitor status page
```

**Recovery:**
```bash
# If multi-region (future enhancement):
# Update DNS to point to backup region
# Verify backup region health

# If single region:
# Wait for GCP restoration
# Verify all services after restoration
# Check data integrity
# Run health checks
```

**Prevention:**
- Multi-region deployment (expensive)
- Regular backups to different region
- Status page for users
- Incident communication plan
- Accept risk for single-region

**Time to Recover:** Hours (depends on GCP)

**Cost:** Very high - complete outage

**Note:** This is why we document it, even if we can't prevent it.

---

## Configuration Failures

### Scenario: Wrong Environment Variables Deployed

**What Happens:**
- Prod deployed with dev config
- Application connects to wrong database
- Wrong API keys used
- Unexpected behavior
- Potential data corruption

**Symptoms:**
```
Error: Database not found
Error: Invalid API key
Unexpected application behavior
Wrong data being displayed
```

**Root Causes:**
1. Manual deployment mistake
2. CI/CD variable misconfiguration
3. .env file copied incorrectly
4. Terraform variable override

**Immediate Actions:**
```bash
# 1. Rollback immediately
gcloud run services update-traffic SERVICE \
  --to-revisions=PREVIOUS_REVISION=100

# 2. Verify current config
gcloud run services describe SERVICE \
  --format="value(spec.template.spec.containers[0].env)"

# 3. Check for data corruption
# Query database for anomalies
```

**Recovery:**
```bash
# Fix and redeploy with correct config
terraform apply \
  -var="env_vars={LOG_LEVEL=info,DB_HOST=prod-db}"

# Or update directly
gcloud run services update SERVICE \
  --update-env-vars=LOG_LEVEL=info,DB_HOST=prod-db
```

**Prevention:**
- Environment-specific variable validation
- Preflight checks (use our Go tool!)
- Separate CI/CD pipelines per environment
- Configuration review in PR
- Automated config validation

**Time to Recover:** 5-10 minutes

---

## Dependency Failures

### Scenario: External API Goes Down

**What Happens:**
- Third-party API becomes unavailable
- Application cannot complete requests
- Timeouts and errors
- User-facing features broken

**Symptoms:**
```
Error: Connection timeout to api.example.com
Error: 503 Service Unavailable
Increased latency
Partial feature failures
```

**Root Causes:**
1. External service outage
2. Rate limit exceeded
3. API key expired
4. Network issues
5. DDoS on external service

**Immediate Actions:**
```bash
# 1. Verify it's external
curl -v https://api.example.com/health

# 2. Check if we're rate limited
# Review API response headers

# 3. Enable fallback if available
# Update feature flags
```

**Recovery:**
```bash
# Option 1: Use cached data
# If caching implemented

# Option 2: Degrade gracefully
# Disable feature temporarily

# Option 3: Switch to backup provider
# If alternative exists

# Option 4: Wait for restoration
# Monitor external status page
```

**Prevention:**
- Implement circuit breakers
- Cache responses when possible
- Graceful degradation
- Timeout configuration
- Retry with exponential backoff
- Monitor external dependencies
- Have backup providers

**Time to Recover:** Depends on external service

---

## Lessons Learned

### Key Takeaways

1. **Failures are normal** - Plan for them
2. **Time matters** - Have runbooks ready
3. **Communication is critical** - Tell users what's happening
4. **Backups save lives** - Test restore procedures
5. **Monitoring catches issues early** - Set up alerts
6. **Documentation prevents panic** - Write it down
7. **Practice recovery** - Run disaster recovery drills

### Failure Response Checklist

- [ ] Acknowledge the incident
- [ ] Assess severity
- [ ] Communicate to stakeholders
- [ ] Follow runbook
- [ ] Document actions taken
- [ ] Verify recovery
- [ ] Write postmortem
- [ ] Implement prevention

---

## Contributing to This Document

**When something breaks:**

1. Document what happened
2. Document how you fixed it
3. Add to this file
4. Update runbooks
5. Share with team

**This document grows with every incident.**

---

## See Also

- [failure-scenarios.md](failure-scenarios.md) - Detailed incident response procedures
- [deployment.md](deployment.md) - Deployment procedures
- [architecture.md](architecture.md) - System architecture

---

**Remember: The best time to write documentation is right after an incident, when the pain is fresh and the details are clear.**
