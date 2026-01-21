# Security Incident Response Runbook

**Last Updated:** 2026-01-18  
**Owner:** Security Team  
**Severity Levels:** P0 (Critical), P1 (High), P2 (Medium), P3 (Low)

---

## Table of Contents

1. [Incident Classification](#incident-classification)
2. [Response Team](#response-team)
3. [Incident Response Procedures](#incident-response-procedures)
4. [Common Security Incidents](#common-security-incidents)
5. [Post-Incident Activities](#post-incident-activities)

---

## Incident Classification

### Severity Definitions

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **P0** | Critical security breach | Immediate (< 15 min) | Data breach, active attack, credential compromise |
| **P1** | High security risk | < 1 hour | Vulnerability exploitation, unauthorized access attempt |
| **P2** | Medium security concern | < 4 hours | Security misconfiguration, suspicious activity |
| **P3** | Low security issue | < 24 hours | Policy violation, minor vulnerability |

---

## Response Team

### Roles and Responsibilities

**Incident Commander (IC)**
- Overall incident coordination
- Decision-making authority
- Communication with stakeholders

**Security Lead**
- Technical investigation
- Threat analysis
- Remediation implementation

**Communications Lead**
- Internal/external communications
- Status updates
- Documentation

**Technical Support**
- System access and changes
- Log analysis
- Evidence collection

### Contact Information

```bash
# Emergency contacts (store securely, not in repo)
IC_PHONE="[REDACTED]"
IC_EMAIL="[REDACTED]"
SECURITY_SLACK="#security-incidents"
ON_CALL_ROTATION="https://your-pagerduty-link"
```

---

## Incident Response Procedures

### Phase 1: Detection and Analysis

**1.1 Incident Detection**

```bash
# Check for security alerts
gcloud logging read \
  "severity>=ERROR AND labels.security=true" \
  --limit 100 \
  --format json

# Check Cloud Armor blocks
gcloud logging read \
  "resource.type=http_load_balancer AND jsonPayload.enforcedSecurityPolicy.name!=\"\"" \
  --limit 100

# Check failed authentication attempts
gcloud logging read \
  "protoPayload.methodName=SetIamPolicy AND protoPayload.status.code!=0" \
  --limit 100
```

**1.2 Initial Assessment**

- [ ] Confirm the incident is real (not false positive)
- [ ] Determine severity level
- [ ] Identify affected systems/data
- [ ] Document initial findings
- [ ] Notify response team

**1.3 Activate Response Team**

```bash
# Send alert to team
curl -X POST $SLACK_WEBHOOK \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🚨 SECURITY INCIDENT DETECTED",
    "attachments": [{
      "color": "danger",
      "fields": [
        {"title": "Severity", "value": "P0", "short": true},
        {"title": "Type", "value": "Unauthorized Access", "short": true},
        {"title": "Status", "value": "INVESTIGATING", "short": true}
      ]
    }]
  }'
```

### Phase 2: Containment

**2.1 Immediate Containment**

```bash
# Revoke compromised credentials immediately
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=COMPROMISED_SA@PROJECT.iam.gserviceaccount.com

# Block malicious IP addresses
gcloud compute security-policies rules create 100 \
  --security-policy=POLICY_NAME \
  --action=deny-403 \
  --src-ip-ranges=MALICIOUS_IP

# Disable compromised user account
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member=user:COMPROMISED_USER@example.com \
  --role=roles/ROLE_NAME

# Scale down affected service
gcloud run services update SERVICE_NAME \
  --max-instances=0 \
  --region=REGION
```

**2.2 Evidence Preservation**

```bash
# Export logs for forensics
gcloud logging read \
  "timestamp>=\"$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)\"" \
  --format json \
  > incident-logs-$(date +%Y%m%d_%H%M%S).json

# Create snapshot of affected resources
gcloud compute disks snapshot DISK_NAME \
  --snapshot-names=incident-snapshot-$(date +%Y%m%d-%H%M%S) \
  --zone=ZONE

# Export IAM policy
gcloud projects get-iam-policy PROJECT_ID \
  --format json \
  > iam-policy-$(date +%Y%m%d_%H%M%S).json
```

**2.3 Short-term Containment**

- [ ] Isolate affected systems
- [ ] Preserve evidence
- [ ] Implement temporary fixes
- [ ] Monitor for lateral movement

### Phase 3: Eradication

**3.1 Root Cause Analysis**

```bash
# Analyze access logs
gcloud logging read \
  "protoPayload.authenticationInfo.principalEmail=SUSPICIOUS_EMAIL" \
  --limit 1000 \
  --format json

# Check for privilege escalation
gcloud logging read \
  "protoPayload.methodName=SetIamPolicy" \
  --limit 100

# Review firewall changes
gcloud logging read \
  "resource.type=gce_firewall_rule AND operation.first=true" \
  --limit 100
```

**3.2 Remove Threat**

```bash
# Remove malicious resources
gcloud compute instances delete MALICIOUS_INSTANCE \
  --zone=ZONE \
  --quiet

# Clean up unauthorized IAM bindings
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member=UNAUTHORIZED_MEMBER \
  --role=ROLE

# Remove backdoors
gcloud compute firewall-rules delete SUSPICIOUS_RULE
```

**3.3 Patch Vulnerabilities**

```bash
# Update vulnerable components
terraform apply -var="patch_version=LATEST"

# Rotate all secrets
./scripts/rotate-secrets.sh

# Update security policies
gcloud compute security-policies update POLICY_NAME \
  --description="Updated after incident $(date +%Y%m%d)"
```

### Phase 4: Recovery

**4.1 Restore Services**

```bash
# Restore from clean backup
./scripts/restore.sh CLEAN_BACKUP_ID

# Redeploy with security fixes
terraform apply

# Verify integrity
./scripts/healthcheck.sh

# Gradually restore traffic
gcloud run services update-traffic SERVICE_NAME \
  --to-revisions=LATEST=10 \
  --region=REGION

# Monitor for 30 minutes, then increase
gcloud run services update-traffic SERVICE_NAME \
  --to-revisions=LATEST=50 \
  --region=REGION
```

**4.2 Verification**

- [ ] Run security scans
- [ ] Verify all credentials rotated
- [ ] Confirm no unauthorized access
- [ ] Test critical functionality
- [ ] Monitor for 24-48 hours

### Phase 5: Post-Incident

**5.1 Documentation**

Create incident report with:
- Timeline of events
- Actions taken
- Root cause analysis
- Impact assessment
- Lessons learned

**5.2 Improvements**

- [ ] Update security policies
- [ ] Enhance monitoring/alerting
- [ ] Implement additional controls
- [ ] Update runbooks
- [ ] Conduct team training

---

## Common Security Incidents

### 1. Credential Compromise

**Symptoms:**
- Unusual API calls
- Access from unexpected locations
- Failed authentication attempts

**Response:**
```bash
# Immediate actions
./scripts/rotate-secrets.sh
gcloud iam service-accounts keys list --iam-account=SA_EMAIL
gcloud iam service-accounts keys delete KEY_ID --iam-account=SA_EMAIL

# Review access logs
gcloud logging read \
  "protoPayload.authenticationInfo.principalEmail=COMPROMISED_EMAIL" \
  --limit 1000
```

### 2. DDoS Attack

**Symptoms:**
- Sudden traffic spike
- High error rates
- Service degradation

**Response:**
```bash
# Enable Cloud Armor rate limiting
gcloud compute security-policies rules update 1000 \
  --security-policy=POLICY_NAME \
  --rate-limit-threshold-count=100 \
  --rate-limit-threshold-interval-sec=60

# Block attacking IPs
gcloud compute security-policies rules create 50 \
  --security-policy=POLICY_NAME \
  --action=deny-403 \
  --src-ip-ranges=ATTACKER_IPS
```

### 3. Data Exfiltration

**Symptoms:**
- Unusual data access patterns
- Large data transfers
- Unauthorized exports

**Response:**
```bash
# Check data access logs
gcloud logging read \
  "resource.type=bigquery_resource OR resource.type=gcs_bucket" \
  --limit 1000

# Enable VPC Service Controls
gcloud access-context-manager perimeters create PERIMETER_NAME \
  --title="Data Protection Perimeter" \
  --resources=projects/PROJECT_NUMBER

# Review and restrict IAM permissions
gcloud projects get-iam-policy PROJECT_ID
```

### 4. Malware/Ransomware

**Symptoms:**
- Encrypted files
- Ransom notes
- Unusual process activity

**Response:**
```bash
# Immediately isolate affected systems
gcloud compute instances stop INSTANCE_NAME --zone=ZONE

# Create forensic snapshot
gcloud compute disks snapshot DISK_NAME \
  --snapshot-names=malware-forensics-$(date +%Y%m%d)

# Restore from clean backup
./scripts/restore.sh CLEAN_BACKUP_ID

# DO NOT pay ransom
# Contact law enforcement
```

### 5. Insider Threat

**Symptoms:**
- Unauthorized data access
- Policy violations
- Suspicious behavior

**Response:**
```bash
# Disable user access immediately
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member=user:INSIDER@example.com \
  --all

# Audit all actions
gcloud logging read \
  "protoPayload.authenticationInfo.principalEmail=INSIDER@example.com" \
  --limit 10000 \
  --format json > insider-audit.json

# Preserve evidence
# Contact HR and legal
```

---

## Post-Incident Activities

### Incident Report Template

```markdown
# Security Incident Report

**Incident ID:** INC-YYYYMMDD-NNN
**Date:** YYYY-MM-DD
**Severity:** P0/P1/P2/P3
**Status:** Resolved/Ongoing

## Executive Summary
[Brief description of the incident]

## Timeline
- **HH:MM** - Incident detected
- **HH:MM** - Response team activated
- **HH:MM** - Containment implemented
- **HH:MM** - Threat eradicated
- **HH:MM** - Services restored

## Impact
- **Systems Affected:** [List]
- **Data Compromised:** [Yes/No/Unknown]
- **Users Affected:** [Number]
- **Downtime:** [Duration]

## Root Cause
[Detailed analysis]

## Actions Taken
1. [Action 1]
2. [Action 2]
3. [Action 3]

## Lessons Learned
- [Lesson 1]
- [Lesson 2]

## Recommendations
1. [Recommendation 1]
2. [Recommendation 2]

## Follow-up Items
- [ ] Update security policies
- [ ] Implement monitoring improvements
- [ ] Conduct team training
```

### Metrics to Track

- **Detection Time:** Time from incident start to detection
- **Response Time:** Time from detection to containment
- **Recovery Time:** Time from containment to full recovery
- **False Positive Rate:** Percentage of false alarms

### Continuous Improvement

1. **Quarterly Reviews**
   - Review all incidents
   - Update runbooks
   - Test response procedures

2. **Annual Exercises**
   - Tabletop exercises
   - Red team assessments
   - Disaster recovery drills

3. **Training**
   - Security awareness training
   - Incident response training
   - Tool-specific training

---

## Emergency Contacts

**Internal:**
- Security Team: #security-incidents
- On-Call: [PagerDuty Link]
- Management: [Contact Info]

**External:**
- GCP Support: https://cloud.google.com/support
- Law Enforcement: [Local Cyber Crime Unit]
- Legal Counsel: [Contact Info]

---

## Related Documentation

- [Architecture](architecture.md)
- [How Things Break](how-things-break.md)
- [Failure Scenarios](failure-scenarios.md)
- [Deployment Procedures](deployment.md)

---

**Remember: In a security incident, speed and accuracy matter. Follow this runbook, document everything, and don't panic.**
