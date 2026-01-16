# Cost Analysis & Optimization

**Infrastructure costs money. This document explains how much and why.**

Most portfolios ignore cost. This is a mistake. In the real world, someone has to pay for it.

---

## Cost Philosophy

> "Cheap is not the goal. Cost-effective is."

Keystone is designed to be:
- **Predictable** - No surprise bills
- **Scalable** - Costs scale with usage
- **Optimized** - Pay for what you use
- **Transparent** - Know where money goes

---

## Monthly Cost Estimates

### Development Environment

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| Cloud Run | 0-5 instances, 1 CPU, 512MB | $0-15 |
| Cloud SQL | db-f1-micro, 10GB, single-zone | $7-10 |
| Cloud Storage | State + backups (~5GB) | $0.10-0.50 |
| Cloud Monitoring | Basic metrics | Free tier |
| Cloud Logging | ~10GB/month | Free tier |
| **Total** | | **$7-25/month** |

### Production Environment

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| Cloud Run | 1-100 instances, 2 CPU, 1GB | $50-200 |
| Cloud SQL | db-custom-2-7680, 100GB, regional | $150-200 |
| Cloud Storage | State + backups (~50GB) | $1-5 |
| Cloud Monitoring | Advanced metrics + alerts | $5-10 |
| Cloud Logging | ~100GB/month | $5-10 |
| Cloud Load Balancing | Included with Cloud Run | $0 |
| **Total** | | **$211-425/month** |

**Note:** Actual costs depend on:
- Request volume
- Database queries
- Storage growth
- Egress traffic
- Monitoring retention

---

## Cost Breakdown by Service

### Cloud Run (Serverless Compute)

**Why We Chose It:**
- ✅ Pay only for actual usage
- ✅ Scales to zero in dev
- ✅ No infrastructure management
- ✅ Built-in load balancing
- ✅ Fast deployments

**Pricing Model:**
```
Cost = (CPU time × CPU price) + (Memory time × Memory price) + (Requests × Request price)

CPU: $0.00002400 per vCPU-second
Memory: $0.00000250 per GiB-second
Requests: $0.40 per million requests
```

**Example Calculation (Production):**
```
Assumptions:
- 1 million requests/month
- Average request duration: 200ms
- 2 vCPU, 1GB memory per instance

CPU cost:
  1M requests × 0.2s × 2 vCPU × $0.000024 = $9.60

Memory cost:
  1M requests × 0.2s × 1GB × $0.0000025 = $0.50

Request cost:
  1M requests × $0.40/million = $0.40

Total: ~$10.50/month for 1M requests
```

**Cost Optimization:**
- Scale to zero in dev (saves ~$50/month)
- Right-size CPU/memory (don't over-provision)
- Use min instances only in prod
- Optimize cold start time
- Cache responses when possible

**vs. EC2 Alternative:**
```
EC2 t3.medium (2 vCPU, 4GB):
- On-demand: ~$30/month (running 24/7)
- Reserved (1 year): ~$20/month
- Still need: Load balancer ($18/month)
- Total: ~$38-48/month minimum

Cloud Run wins for:
- Variable traffic
- Development environments
- Cost predictability
- Zero ops overhead
```

---

### Cloud SQL (Managed PostgreSQL)

**Why We Chose It:**
- ✅ Fully managed (no ops)
- ✅ Automated backups
- ✅ High availability option
- ✅ Point-in-time recovery
- ✅ Automatic storage scaling

**Pricing Model:**
```
Cost = (Instance hours × Instance price) + (Storage × Storage price) + (Backup storage × Backup price)

Dev (db-f1-micro):
  Instance: $0.0150/hour = ~$11/month
  Storage: $0.17/GB/month
  Backups: $0.08/GB/month

Prod (db-custom-2-7680):
  Instance: $0.2070/hour = ~$151/month
  Storage: $0.17/GB/month
  Backups: $0.08/GB/month
```

**Example Calculation (Production):**
```
Instance: $151/month
Storage (100GB): $17/month
Backups (30GB): $2.40/month
Total: ~$170/month
```

**Cost Optimization:**
- Use db-f1-micro in dev (saves ~$140/month)
- Enable auto-increase storage (prevent over-provisioning)
- Set backup retention to 7-30 days (not forever)
- Use regional only in prod (saves ~$150/month in dev)
- Schedule maintenance windows
- Monitor query performance (slow queries = more CPU)

**vs. Self-Managed Alternative:**
```
PostgreSQL on Compute Engine:
- Instance (e2-medium): ~$25/month
- Disk (100GB SSD): ~$17/month
- Your time for:
  - Setup and configuration
  - Backup management
  - Security patches
  - Monitoring setup
  - High availability
  - Disaster recovery
- Total: ~$42/month + ops time

Cloud SQL wins for:
- Ops time savings
- Built-in HA
- Automated backups
- Security patches
- Peace of mind
```

---

### Cloud Storage (Object Storage)

**Why We Chose It:**
- ✅ Extremely cheap
- ✅ Highly durable (11 9's)
- ✅ Versioning support
- ✅ Lifecycle policies
- ✅ Global accessibility

**Pricing Model:**
```
Storage: $0.020/GB/month (Standard)
Operations: $0.05 per 10,000 Class A operations
Egress: $0.12/GB (first 1TB)
```

**Example Calculation:**
```
Terraform state: ~1GB
Backups: ~50GB (with 30-day retention)
Total storage: 51GB × $0.020 = $1.02/month

Operations: ~1,000/month = $0.005
Egress: ~5GB/month = $0.60

Total: ~$1.63/month
```

**Cost Optimization:**
- Use lifecycle policies (auto-delete old backups)
- Compress backups before upload
- Use Nearline for old backups ($0.010/GB)
- Use Coldline for archives ($0.004/GB)
- Monitor egress (downloads cost money)

---

### Cloud Monitoring & Logging

**Why We Chose It:**
- ✅ Integrated with GCP services
- ✅ Generous free tier
- ✅ No setup required
- ✅ Powerful query language
- ✅ Built-in alerting

**Pricing Model:**
```
Monitoring:
  First 150MB/month: Free
  Additional: $0.2580/MB

Logging:
  First 50GB/month: Free
  Additional: $0.50/GB
```

**Example Calculation (Production):**
```
Monitoring data: ~100MB/month (within free tier)
Logs: ~100GB/month
  First 50GB: Free
  Next 50GB: $25/month

Total: ~$25/month
```

**Cost Optimization:**
- Exclude verbose logs (debug level in prod)
- Set log retention to 30 days (not forever)
- Use sampling for high-volume logs
- Export old logs to Cloud Storage
- Use log-based metrics (cheaper than custom metrics)
- Delete unused alert policies

---

## Cost Scaling Scenarios

### Scenario 1: Startup (Low Traffic)
```
Traffic: 100K requests/month
Database: Light usage

Cloud Run: $1-2/month
Cloud SQL: $170/month
Storage: $2/month
Monitoring: Free tier
Total: ~$173/month
```

### Scenario 2: Growing (Medium Traffic)
```
Traffic: 10M requests/month
Database: Moderate usage

Cloud Run: $100-150/month
Cloud SQL: $200/month
Storage: $5/month
Monitoring: $10/month
Total: ~$315/month
```

### Scenario 3: Scale (High Traffic)
```
Traffic: 100M requests/month
Database: Heavy usage

Cloud Run: $1,000-1,500/month
Cloud SQL: $300/month (larger instance)
Storage: $20/month
Monitoring: $50/month
Total: ~$1,370/month
```

**Key Insight:** Costs scale roughly linearly with traffic, not exponentially.

---

## Cost Comparison: Cloud Run vs. EC2

### Cloud Run (Serverless)

**Pros:**
- ✅ Pay only for actual usage
- ✅ Scales to zero
- ✅ No infrastructure management
- ✅ Fast deployments
- ✅ Built-in load balancing

**Cons:**
- ❌ Cold starts (mitigated with min instances)
- ❌ 15-minute max request timeout
- ❌ Stateless only

**Best For:**
- Variable traffic
- Development environments
- API services
- Microservices

### EC2 (Traditional)

**Pros:**
- ✅ Full control
- ✅ No cold starts
- ✅ Can run stateful workloads
- ✅ Predictable performance

**Cons:**
- ❌ Pay 24/7 even if idle
- ❌ Infrastructure management
- ❌ Need separate load balancer
- ❌ Slower deployments

**Best For:**
- Constant high traffic
- Stateful applications
- Long-running processes
- Specific OS requirements

### Cost Comparison Table

| Metric | Cloud Run | EC2 (t3.medium) |
|--------|-----------|-----------------|
| Base cost | $0 (scales to zero) | ~$30/month |
| Load balancer | Included | +$18/month |
| Auto-scaling | Included | +$0 (ASG free) |
| SSL certificate | Included | +$0 (Let's Encrypt) |
| Deployment | Included | DIY |
| Monitoring | Included | +$5-10/month |
| **Total (idle)** | **$0** | **~$53/month** |
| **Total (1M req)** | **~$10** | **~$53/month** |
| **Total (10M req)** | **~$100** | **~$53/month** |

**Conclusion:** Cloud Run is cheaper for variable/low traffic. EC2 becomes competitive at very high constant traffic.

---

## Cost Optimization Strategies

### 1. Right-Size Resources

**Don't:**
```hcl
# Over-provisioned
cpu_limit    = "4000m"  # 4 CPUs
memory_limit = "4Gi"    # 4GB
```

**Do:**
```hcl
# Right-sized based on metrics
cpu_limit    = "1000m"  # 1 CPU
memory_limit = "512Mi"  # 512MB
```

**Savings:** ~75% on compute costs

### 2. Use Environment-Specific Configs

**Don't:**
```hcl
# Same config for dev and prod
min_instances = "5"
max_instances = "100"
```

**Do:**
```hcl
# Dev
min_instances = "0"  # Scale to zero
max_instances = "5"

# Prod
min_instances = "1"  # Keep warm
max_instances = "100"
```

**Savings:** ~$50/month in dev

### 3. Implement Caching

**Impact:**
- Reduces database queries
- Lowers Cloud Run CPU time
- Decreases response time

**Savings:** 30-50% on compute costs

### 4. Optimize Database Queries

**Impact:**
- Faster queries = less CPU time
- Fewer connections needed
- Smaller instance possible

**Savings:** 20-40% on database costs

### 5. Set Up Budget Alerts

```bash
# Create budget alert
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Keystone Monthly Budget" \
  --budget-amount=500 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100
```

---

## Cost Monitoring

### Daily Checks
```bash
# Check current month costs
gcloud billing accounts describe BILLING_ACCOUNT_ID

# Check by service
gcloud billing accounts list-services \
  --billing-account=BILLING_ACCOUNT_ID
```

### Weekly Review
- Review cost breakdown in GCP Console
- Check for unexpected spikes
- Verify auto-scaling behavior
- Review storage growth

### Monthly Actions
- Analyze cost trends
- Right-size resources
- Clean up unused resources
- Update cost estimates

---

## Cost Attribution

### By Environment

```
Dev: ~$25/month (5%)
Prod: ~$400/month (95%)
Total: ~$425/month
```

### By Service Type

```
Compute (Cloud Run): ~$150/month (35%)
Database (Cloud SQL): ~$200/month (47%)
Storage: ~$5/month (1%)
Monitoring/Logging: ~$25/month (6%)
Other: ~$45/month (11%)
```

### By Cost Type

```
Fixed costs: ~$170/month (40%)
  - Database instance
  - Min instances
  
Variable costs: ~$255/month (60%)
  - Request-based compute
  - Storage growth
  - Egress
```

---

## ROI Analysis

### Cost of Alternatives

**Self-Managed on EC2:**
- Infrastructure: ~$100/month
- Your time (10 hrs/month @ $50/hr): $500/month
- Total: ~$600/month

**Keystone (Managed Services):**
- Infrastructure: ~$425/month
- Your time (2 hrs/month @ $50/hr): $100/month
- Total: ~$525/month

**Savings:** ~$75/month + 8 hours of your time

### Value Delivered

- ✅ Zero infrastructure management
- ✅ Automated backups and recovery
- ✅ Built-in monitoring and alerting
- ✅ High availability
- ✅ Security patches automatic
- ✅ Scales automatically
- ✅ Focus on features, not ops

**ROI:** Positive from day one

---

## Budget Recommendations

### Startup Budget
```
Monthly: $200-300
Annual: $2,400-3,600

Covers:
- Dev + Prod environments
- Light to moderate traffic
- Basic monitoring
- 30-day backup retention
```

### Growth Budget
```
Monthly: $500-1,000
Annual: $6,000-12,000

Covers:
- Multiple environments
- Moderate to high traffic
- Advanced monitoring
- Longer backup retention
- Staging environment
```

### Scale Budget
```
Monthly: $1,500-3,000
Annual: $18,000-36,000

Covers:
- Multi-region deployment
- Very high traffic
- Comprehensive monitoring
- Long-term data retention
- DR environment
```

---

## Key Takeaways

1. **Predictable Costs** - Mostly fixed, scales linearly
2. **Right-Sized** - Not over-provisioned
3. **Optimized** - Scales to zero in dev
4. **Transparent** - Know where money goes
5. **Cost-Effective** - Cheaper than self-managed when including ops time

**Bottom Line:** Keystone costs ~$425/month in production, which is reasonable for a production-grade, fully-managed infrastructure.

---

## See Also

- [architecture.md](architecture.md) - Why we chose these services
- [deployment.md](deployment.md) - How to deploy cost-effectively
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator) - Estimate your costs
