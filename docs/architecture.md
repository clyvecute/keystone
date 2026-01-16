# Architecture

## Overview

Keystone is a production-ready infrastructure layer designed to support the Configra application. It demonstrates cloud-native best practices, infrastructure as code, and operational excellence.

## System Design

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS
                         ▼
              ┌──────────────────────┐
              │   Cloud Load Balancer │
              │   (Managed by GCP)    │
              └──────────┬───────────┘
                         │
                         │
                         ▼
              ┌──────────────────────┐
              │   Cloud Run Service   │
              │   (Configra App)      │
              │   - Auto-scaling      │
              │   - Serverless        │
              └──────────┬───────────┘
                         │
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
    ┌─────────┐   ┌──────────┐   ┌──────────┐
    │ Cloud   │   │ Cloud    │   │ Secret   │
    │ SQL     │   │ Storage  │   │ Manager  │
    │ (DB)    │   │ (Backup) │   │ (Secrets)│
    └─────────┘   └──────────┘   └──────────┘
          │
          │
          ▼
    ┌──────────────────────────────────────┐
    │   Monitoring & Observability          │
    │   - Cloud Monitoring                  │
    │   - Cloud Logging                     │
    │   - Uptime Checks                     │
    │   - Alert Policies                    │
    └──────────────────────────────────────┘
```

## Components

### 1. Compute Layer (Cloud Run)

**Purpose**: Serverless container platform for running Configra

**Key Features**:
- Auto-scaling from 0 to 100 instances
- Pay-per-use pricing
- Built-in load balancing
- Automatic HTTPS
- Zero-downtime deployments

**Configuration**:
- **Dev**: 0-5 instances, 1 CPU, 512MB RAM
- **Prod**: 1-100 instances, 2 CPU, 1GB RAM

### 2. Database Layer (Cloud SQL)

**Purpose**: Managed PostgreSQL database

**Key Features**:
- Automated backups (daily)
- Point-in-time recovery (prod)
- High availability (prod)
- Automatic storage scaling
- Connection pooling

**Configuration**:
- **Dev**: Single-zone, db-f1-micro, 10GB
- **Prod**: Multi-zone, db-custom-2-7680, 100GB

### 3. Storage Layer (Cloud Storage)

**Purpose**: Object storage for backups and artifacts

**Buckets**:
- `keystone-terraform-state-{env}`: Terraform state
- `keystone-backups`: Database and config backups
- `{app}-{env}-monitoring`: Monitoring configs

### 4. Security Layer

**IAM Roles**:
- Service accounts with minimal permissions
- Workload Identity for GitHub Actions
- Secret Manager for sensitive data

**Network Security**:
- VPC with private subnets
- Firewall rules for controlled access
- SSL/TLS everywhere

### 5. Monitoring Layer

**Components**:
- **Cloud Monitoring**: Metrics and dashboards
- **Cloud Logging**: Centralized logs
- **Uptime Checks**: Availability monitoring
- **Alert Policies**: Automated incident response

**Metrics Tracked**:
- Request rate and latency
- Error rates (4xx, 5xx)
- Resource utilization (CPU, memory)
- Database performance
- Container instance count

## Data Flow

### Request Flow
1. User makes HTTPS request
2. Cloud Load Balancer routes to Cloud Run
3. Cloud Run instance processes request
4. Application queries Cloud SQL if needed
5. Response returned to user

### Deployment Flow
1. Code pushed to GitHub
2. GitHub Actions triggers build
3. Container built and pushed to GCR
4. Terraform applies infrastructure changes
5. Cloud Run deploys new revision
6. Health checks validate deployment
7. Traffic shifted to new revision

### Backup Flow
1. Scheduled job triggers backup script
2. Cloud SQL backup created
3. Terraform state copied to GCS
4. Monitoring configs exported
5. Backup manifest created
6. Tarball uploaded to GCS
7. Old backups cleaned up

## Scalability

### Horizontal Scaling
- Cloud Run auto-scales based on:
  - Request concurrency
  - CPU utilization
  - Custom metrics

### Vertical Scaling
- Database can be resized without downtime
- Cloud Run resources adjustable per revision

### Geographic Distribution
- Multi-region deployment possible
- Cloud CDN for static assets
- Global load balancing

## High Availability

### Application Layer
- Multiple Cloud Run instances
- Automatic health checks
- Zero-downtime deployments
- Automatic failover

### Database Layer
- Regional configuration (prod)
- Automated backups
- Point-in-time recovery
- Read replicas (future)

### Disaster Recovery
- Automated backups (daily)
- 30-day retention
- Cross-region backup storage
- Documented restore procedures

## Security Architecture

### Defense in Depth
1. **Network**: VPC, firewall rules, private IPs
2. **Application**: IAM, service accounts, least privilege
3. **Data**: Encryption at rest and in transit
4. **Secrets**: Secret Manager, no secrets in code
5. **Monitoring**: Audit logs, anomaly detection

### Compliance
- Encryption at rest (AES-256)
- Encryption in transit (TLS 1.2+)
- Audit logging enabled
- Access controls enforced

## Cost Optimization

### Strategies
- Cloud Run scales to zero in dev
- Right-sized database instances
- Lifecycle policies on storage
- Committed use discounts (prod)
- Budget alerts configured

### Estimated Costs
- **Dev**: ~$20-50/month
- **Prod**: ~$200-500/month (depends on traffic)

## Technology Choices

### Why Cloud Run?
- Serverless = no infrastructure management
- Auto-scaling = cost-effective
- Fast deployments
- Built-in observability

### Why Cloud SQL?
- Fully managed
- Automated backups
- High availability options
- PostgreSQL compatibility

### Why Terraform?
- Infrastructure as code
- Version controlled
- Reproducible
- Industry standard

## Future Enhancements

### Planned
- [ ] Multi-region deployment
- [ ] Read replicas for database
- [ ] CDN integration
- [ ] Advanced monitoring with Grafana
- [ ] Chaos engineering tests

### Considered
- [ ] Service mesh (Istio)
- [ ] Kubernetes migration
- [ ] Serverless database (Cloud Spanner)
- [ ] Edge computing (Cloud Functions)
