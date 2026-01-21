# Security Architecture & Compliance

**Last Updated:** 2026-01-18  
**Classification:** Internal  
**Owner:** Security Team

---

## Table of Contents

1. [Security Overview](#security-overview)
2. [Defense in Depth](#defense-in-depth)
3. [Encryption](#encryption)
4. [Access Control](#access-control)
5. [Network Security](#network-security)
6. [Application Security](#application-security)
7. [Data Protection](#data-protection)
8. [Monitoring & Detection](#monitoring--detection)
9. [Compliance](#compliance)
10. [Security Best Practices](#security-best-practices)

---

## Security Overview

Keystone implements enterprise-grade security controls across all layers of the infrastructure stack. Our security posture is designed to:

- **Prevent** unauthorized access and attacks
- **Detect** security incidents quickly
- **Respond** effectively to threats
- **Recover** rapidly from incidents

### Security Principles

1. **Defense in Depth** - Multiple layers of security controls
2. **Least Privilege** - Minimal permissions required for operation
3. **Zero Trust** - Never trust, always verify
4. **Security by Default** - Secure configurations out of the box
5. **Continuous Monitoring** - Real-time threat detection

---

## Defense in Depth

### Layer 1: Network Security

**VPC Isolation**
- Custom VPC with private subnets
- No auto-created subnetworks
- Private Google Access enabled
- VPC Flow Logs for traffic analysis

**Firewall Rules**
```hcl
# Deny all egress by default
resource "google_compute_firewall" "deny_all_egress" {
  direction = "EGRESS"
  priority  = 65534
  deny {
    protocol = "all"
  }
}

# Allow only necessary egress (Google APIs)
resource "google_compute_firewall" "allow_google_apis_egress" {
  direction = "EGRESS"
  priority  = 1000
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  destination_ranges = ["199.36.153.8/30"]
}
```

**Cloud Armor Protection**
- DDoS protection
- Rate limiting (1000 req/min per IP)
- OWASP ModSecurity Core Rule Set
- XSS and SQL injection prevention
- Geo-blocking capabilities

### Layer 2: Application Security

**Binary Authorization**
- Container image verification
- Attestation required in production
- Only trusted images allowed

**Cloud Run Security**
- Service accounts with minimal permissions
- No privileged containers
- Automatic HTTPS/TLS
- Request authentication

### Layer 3: Data Security

**Encryption at Rest**
- Google-managed encryption keys (default)
- Customer-managed encryption keys (CMEK) support
- Database encryption enabled
- Secret Manager for sensitive data

**Encryption in Transit**
- TLS 1.2+ everywhere
- SSL required for database connections
- HTTPS-only for all services

### Layer 4: Identity & Access

**IAM Hierarchy**
```
Organization
└── Project
    ├── Service Accounts (minimal permissions)
    │   ├── Cloud Run SA (logging, metrics, secrets)
    │   └── GitHub Actions SA (deployment only)
    └── Workload Identity (no long-lived keys)
```

**Access Controls**
- Workload Identity for CI/CD (no service account keys)
- Service accounts per environment
- Role-based access control (RBAC)
- Regular access reviews

### Layer 5: Monitoring & Detection

**Security Monitoring**
- Cloud Logging for audit trails
- Security Command Center integration
- Automated security scanning (tfsec, Trivy, Checkov)
- Real-time alerting

---

## Encryption

### Encryption at Rest

**Database Encryption**
```hcl
resource "google_sql_database_instance" "main" {
  settings {
    disk_encryption_configuration {
      kms_key_name = var.kms_key_name  # CMEK support
    }
  }
}
```

**Storage Encryption**
- All GCS buckets encrypted by default
- Versioning enabled for audit trail
- Lifecycle policies for data retention

**Secret Management**
- Secrets stored in Secret Manager
- Automatic encryption
- Version control and rotation
- Audit logging enabled

### Encryption in Transit

**TLS Configuration**
- Minimum TLS 1.2
- Strong cipher suites only
- Certificate management automated
- HTTPS enforcement

**Database Connections**
```hcl
ip_configuration {
  require_ssl = true
  private_network = var.vpc_id
}
```

### Key Management

**Key Rotation Policy**
- Database passwords: 90 days
- Service account keys: 90 days
- API keys: 180 days
- Automated rotation script available

---

## Access Control

### IAM Roles and Permissions

**Service Account Permissions**

```hcl
# Cloud Run Service Account
resource "google_project_iam_member" "app_logging" {
  role = "roles/logging.logWriter"
}

resource "google_project_iam_member" "app_metrics" {
  role = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "app_secret_accessor" {
  role = "roles/secretmanager.secretAccessor"
}
```

**GitHub Actions (CI/CD)**
- Workload Identity Federation
- No long-lived service account keys
- Deployment permissions only
- Separate accounts for dev/prod

### Authentication & Authorization

**Service-to-Service**
- Service account authentication
- IAM-based authorization
- No API keys in code

**User Access**
- Google Cloud Identity
- MFA required
- Regular access reviews
- Principle of least privilege

---

## Network Security

### VPC Configuration

**Subnet Design**
```
10.0.0.0/24 - Application subnet
Private Google Access: Enabled
Flow Logs: Enabled (10min interval, 50% sampling)
```

**Firewall Strategy**
1. Deny all by default
2. Allow specific required traffic
3. Log all denied connections
4. Regular rule audits

### Cloud Armor Rules

**Rate Limiting**
- 1000 requests/minute per IP
- 10-minute ban on violation
- Adaptive protection enabled

**OWASP Protection**
```hcl
# XSS Protection
rule {
  action = "deny(403)"
  match {
    expr {
      expression = "evaluatePreconfiguredExpr('xss-stable')"
    }
  }
}

# SQL Injection Protection
rule {
  action = "deny(403)"
  match {
    expr {
      expression = "evaluatePreconfiguredExpr('sqli-stable')"
    }
  }
}
```

### DDoS Protection

- Cloud Armor DDoS protection
- Auto-scaling to handle traffic spikes
- Rate limiting per IP
- Geographic restrictions (if needed)

---

## Application Security

### Container Security

**Image Scanning**
```yaml
# Trivy vulnerability scanning
- name: Run Trivy scanner
  uses: aquasecurity/trivy-action@master
  with:
    severity: 'CRITICAL,HIGH,MEDIUM'
```

**Binary Authorization**
- Only signed images in production
- Attestation verification
- Automated policy enforcement

### Dependency Management

**Automated Scanning**
- Snyk for dependency vulnerabilities
- OSSF Scorecard for supply chain security
- Regular dependency updates

### Secrets Management

**Never in Code**
```bash
# Good - Using Secret Manager
gcloud secrets versions access latest --secret="db-password"

# Bad - Hardcoded
DB_PASSWORD="hardcoded123"
```

**Secret Rotation**
```bash
# Automated rotation
./scripts/rotate-secrets.sh

# Manual rotation if needed
gcloud secrets versions add SECRET_NAME --data-file=-
```

---

## Data Protection

### Data Classification

| Level | Description | Examples | Controls |
|-------|-------------|----------|----------|
| **Public** | Publicly available | Documentation | None required |
| **Internal** | Internal use only | Logs, metrics | Access control |
| **Confidential** | Sensitive business data | User data, configs | Encryption + access control |
| **Restricted** | Highly sensitive | Credentials, PII | Encryption + strict access + audit |

### Data Lifecycle

**Collection**
- Minimal data collection
- Purpose limitation
- Consent management

**Storage**
- Encryption at rest
- Access controls
- Retention policies

**Processing**
- Encryption in transit
- Audit logging
- Data minimization

**Deletion**
- Secure deletion procedures
- Backup retention limits
- Compliance with regulations

### Backup & Recovery

**Backup Strategy**
- Daily automated backups
- 30-day retention
- Cross-region backup storage
- Encrypted backups

**Recovery Procedures**
- Documented restore process
- Regular restore testing
- RTO: 4 hours
- RPO: 24 hours

---

## Monitoring & Detection

### Security Monitoring

**Security Logging & Long-term Audit**
- **Cloud Logging**: Real-time audit trails and application logs.
- **BigQuery Audit Sink**: High-value security signals (IAM changes, secret access) are automatically streamed to BigQuery for 12-month+ forensic retention.
- **Compliance Reporting**: Use `make security-audit` to generate summary reports from recorded audit data.

**Alerting Rules**
- Failed authentication attempts
- IAM policy changes
- Firewall rule modifications
- Unusual data access patterns
- Cloud Armor blocks
- Database encryption key (KMS) rotation failure

### Threat Detection

**Automated Scanning**
- Daily security scans
- Continuous vulnerability assessment
- Secrets detection (Gitleaks, TruffleHog)
- Infrastructure scanning (tfsec, Checkov)

**Incident Response**
- 24/7 monitoring
- Automated alerting
- Documented runbooks
- Regular drills

---

## Compliance

### Standards & Frameworks

**Implemented Controls**
- [x] Encryption at rest and in transit
- [x] Access controls and IAM
- [x] Audit logging
- [x] Network security
- [x] Incident response procedures
- [x] Backup and recovery
- [x] Vulnerability management

**Compliance Readiness**
- **SOC 2 Type II** - Ready (GCP provides compliant infrastructure)
- **ISO 27001** - Ready (security controls documented)
- **GDPR** - Partial (data protection controls in place)
- **HIPAA** - Not implemented (requires additional controls)

### Audit Trail

**What We Log**
- All IAM changes
- Database access
- API calls
- Security events
- Configuration changes
- Deployment activities

**Log Retention**
- Security logs: 1 year
- Audit logs: 1 year
- Application logs: 90 days
- Access logs: 180 days

---

## Security Best Practices

### Development

**Secure Coding**
- [ ] No secrets in code
- [ ] Input validation
- [ ] Output encoding
- [ ] Error handling
- [ ] Security testing

**Code Review**
- [ ] Security review required
- [ ] Automated security scanning
- [ ] Dependency checks
- [ ] Secrets detection

### Deployment

**Pre-Deployment**
- [ ] Security scan passed
- [ ] Terraform plan reviewed
- [ ] Secrets rotated
- [ ] Backup created

**Post-Deployment**
- [ ] Health checks passed
- [ ] Monitoring verified
- [ ] Logs reviewed
- [ ] Security alerts checked

### Operations

**Regular Activities**
- [ ] Weekly: Review security alerts
- [ ] Monthly: Access review
- [ ] Quarterly: Secret rotation
- [ ] Annually: Security audit

**Incident Response**
- [ ] Runbooks updated
- [ ] Team trained
- [ ] Contacts current
- [ ] Drills conducted

---

## Security Checklist

### Infrastructure Security

- [x] VPC with private subnets
- [x] Firewall rules configured
- [x] Cloud Armor enabled
- [x] Private Google Access
- [x] VPC Flow Logs enabled
- [x] DDoS protection active

### Application Security

- [x] Service accounts with minimal permissions
- [x] Workload Identity for CI/CD
- [x] Binary Authorization configured
- [x] Container scanning enabled
- [x] Dependency scanning active
- [x] Secrets in Secret Manager

### Data Security

- [x] Encryption at rest
- [x] Encryption in transit
- [x] SSL required for database
- [x] Automated backups
- [x] Backup encryption
- [x] Data retention policies

### Monitoring & Response

- [x] Security logging enabled
- [x] Alerting configured
- [x] Incident response runbook
- [x] Automated security scanning
- [x] Audit trail maintained
- [x] Regular security reviews

---

## Security Contacts

**Report Security Issues:**
- Email: security@yourdomain.com
- Slack: #security-incidents
- On-Call: [PagerDuty Link]

**Security Team:**
- Security Lead: [Name]
- Incident Commander: [Name]
- Compliance Officer: [Name]

---

## Related Documentation

- [Security Incident Response](security-incident-response.md)
- [How Things Break](how-things-break.md)
- [Architecture](architecture.md)
- [Deployment Procedures](deployment.md)

---

**Last Security Audit:** 2026-01-18  
**Next Scheduled Audit:** 2026-04-18  
**Compliance Status:** Compliant
