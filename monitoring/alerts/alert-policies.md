# Alert Configurations for Keystone

## High Error Rate
- **Name**: High Error Rate
- **Condition**: 5xx error rate > 5% for 1 minute
- **Severity**: Critical
- **Action**: Page on-call engineer

## High Latency
- **Name**: High Response Latency
- **Condition**: p95 latency > 1000ms for 5 minutes
- **Severity**: Warning
- **Action**: Notify team channel

## Service Down
- **Name**: Service Unavailable
- **Condition**: Uptime check fails for 5 minutes
- **Severity**: Critical
- **Action**: Page on-call engineer

## Database Connection Pool Exhaustion
- **Name**: Database Connection Pool Near Limit
- **Condition**: Active connections > 80% of max for 5 minutes
- **Severity**: Warning
- **Action**: Notify team channel

## High CPU Usage
- **Name**: High CPU Utilization
- **Condition**: CPU usage > 80% for 10 minutes
- **Severity**: Warning
- **Action**: Notify team channel

## High Memory Usage
- **Name**: High Memory Utilization
- **Condition**: Memory usage > 90% for 5 minutes
- **Severity**: Critical
- **Action**: Auto-scale or page on-call

## SSL Certificate Expiring
- **Name**: SSL Certificate Expiring Soon
- **Condition**: Certificate expires in < 30 days
- **Severity**: Warning
- **Action**: Notify team channel

## Backup Failure
- **Name**: Backup Failed
- **Condition**: Backup job failed
- **Severity**: Critical
- **Action**: Page on-call engineer

## Deployment Failure
- **Name**: Deployment Failed
- **Condition**: Deployment pipeline failed
- **Severity**: Warning
- **Action**: Notify team channel

## Terraform Drift
- **Name**: Infrastructure Drift Detected
- **Condition**: Terraform plan shows changes
- **Severity**: Warning
- **Action**: Notify team channel
