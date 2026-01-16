#!/bin/bash
set -euo pipefail

# Health check script for Keystone infrastructure
# Validates service availability and health

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_URL="${1:-}"
TIMEOUT="${TIMEOUT:-10}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

# Health check results
CHECKS_PASSED=0
CHECKS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((CHECKS_PASSED++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((CHECKS_FAILED++))
}

# HTTP health check
check_http_endpoint() {
    local url="$1"
    local expected_status="${2:-200}"
    local description="$3"
    
    log_info "Checking: $description"
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        "$url" || echo "000")
    
    if [ "$status_code" = "$expected_status" ]; then
        log_success "$description (HTTP $status_code)"
        return 0
    else
        log_error "$description (HTTP $status_code, expected $expected_status)"
        return 1
    fi
}

# Check with retries
check_with_retries() {
    local url="$1"
    local expected_status="${2:-200}"
    local description="$3"
    
    for i in $(seq 1 "$MAX_RETRIES"); do
        if check_http_endpoint "$url" "$expected_status" "$description"; then
            return 0
        fi
        
        if [ "$i" -lt "$MAX_RETRIES" ]; then
            log_warning "Retry $i/$MAX_RETRIES in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
    done
    
    return 1
}

# Check response time
check_response_time() {
    local url="$1"
    local max_time="${2:-1000}" # milliseconds
    local description="$3"
    
    log_info "Checking response time: $description"
    
    local response_time
    response_time=$(curl -s -o /dev/null -w "%{time_total}" \
        --max-time "$TIMEOUT" \
        "$url" || echo "999")
    
    # Convert to milliseconds
    response_time=$(echo "$response_time * 1000" | bc)
    response_time=${response_time%.*}
    
    if [ "$response_time" -lt "$max_time" ]; then
        log_success "$description (${response_time}ms)"
        return 0
    else
        log_error "$description (${response_time}ms, max ${max_time}ms)"
        return 1
    fi
}

# Check JSON response
check_json_response() {
    local url="$1"
    local jq_filter="$2"
    local expected_value="$3"
    local description="$4"
    
    log_info "Checking JSON response: $description"
    
    local response
    response=$(curl -s --max-time "$TIMEOUT" "$url" || echo "{}")
    
    local actual_value
    actual_value=$(echo "$response" | jq -r "$jq_filter" 2>/dev/null || echo "null")
    
    if [ "$actual_value" = "$expected_value" ]; then
        log_success "$description"
        return 0
    else
        log_error "$description (got: $actual_value, expected: $expected_value)"
        return 1
    fi
}

# Check SSL certificate
check_ssl_certificate() {
    local url="$1"
    local description="$2"
    
    log_info "Checking SSL certificate: $description"
    
    local domain
    domain=$(echo "$url" | sed -e 's|^https://||' -e 's|/.*$||')
    
    local expiry_date
    expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -n "$expiry_date" ]; then
        local expiry_epoch
        expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
        local now_epoch
        now_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - now_epoch) / 86400 ))
        
        if [ "$days_until_expiry" -gt 30 ]; then
            log_success "$description (expires in $days_until_expiry days)"
            return 0
        elif [ "$days_until_expiry" -gt 0 ]; then
            log_warning "$description (expires in $days_until_expiry days - renewal recommended)"
            return 0
        else
            log_error "$description (expired $days_until_expiry days ago)"
            return 1
        fi
    else
        log_error "$description (could not retrieve certificate)"
        return 1
    fi
}

# Main health checks
run_health_checks() {
    if [ -z "$SERVICE_URL" ]; then
        log_error "Usage: $0 <service_url>"
        log_info "Example: $0 https://configra-dev-abc123.run.app"
        exit 1
    fi
    
    log_info "Running health checks for: $SERVICE_URL"
    echo ""
    
    # Basic availability
    check_with_retries "$SERVICE_URL" "200" "Service availability"
    
    # Health endpoint
    check_with_retries "${SERVICE_URL}/health" "200" "Health endpoint"
    
    # Response time
    check_response_time "$SERVICE_URL" "1000" "Response time"
    
    # SSL certificate (if HTTPS)
    if [[ $SERVICE_URL == https://* ]]; then
        check_ssl_certificate "$SERVICE_URL" "SSL certificate"
    fi
    
    # Metrics endpoint (if available)
    check_http_endpoint "${SERVICE_URL}/metrics" "200" "Metrics endpoint" || true
    
    # API version (if available)
    check_json_response "${SERVICE_URL}/health" ".status" "healthy" "Health status" || true
}

# Print summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Health Check Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "Passed: ${GREEN}${CHECKS_PASSED}${NC}"
    echo -e "Failed: ${RED}${CHECKS_FAILED}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$CHECKS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All health checks passed${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some health checks failed${NC}"
        exit 1
    fi
}

# Main execution
main() {
    run_health_checks
    print_summary
}

# Run main function
main "$@"
