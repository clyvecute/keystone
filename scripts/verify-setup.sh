#!/bin/bash
# Verification script for Keystone setup

echo "🔍 Verifying Keystone Repository Structure..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1 (missing)"
        ((ERRORS++))
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
    else
        echo -e "${RED}✗${NC} $1/ (missing)"
        ((ERRORS++))
    fi
}

echo "📁 Root Files:"
check_file "README.md"
check_file "Makefile"
check_file ".env.example"
check_file ".gitignore"
check_file "LICENSE"
check_file "CONTRIBUTING.md"
check_file "SETUP.md"

echo ""
echo "🏗️ Terraform Structure:"
check_dir "terraform"
check_file "terraform/backend.tf"
check_file "terraform/providers.tf"
check_file "terraform/variables.tf"

echo ""
echo "🔧 Terraform Modules:"
check_dir "terraform/modules/network"
check_file "terraform/modules/network/main.tf"
check_file "terraform/modules/network/variables.tf"
check_file "terraform/modules/network/outputs.tf"

check_dir "terraform/modules/compute"
check_file "terraform/modules/compute/main.tf"
check_file "terraform/modules/compute/variables.tf"
check_file "terraform/modules/compute/outputs.tf"

check_dir "terraform/modules/database"
check_file "terraform/modules/database/main.tf"
check_file "terraform/modules/database/variables.tf"
check_file "terraform/modules/database/outputs.tf"

check_dir "terraform/modules/monitoring"
check_file "terraform/modules/monitoring/main.tf"
check_file "terraform/modules/monitoring/variables.tf"
check_file "terraform/modules/monitoring/outputs.tf"

echo ""
echo "🌍 Environments:"
check_dir "terraform/environments/dev"
check_file "terraform/environments/dev/main.tf"
check_file "terraform/environments/dev/variables.tf"
check_file "terraform/environments/dev/outputs.tf"

check_dir "terraform/environments/prod"
check_file "terraform/environments/prod/main.tf"
check_file "terraform/environments/prod/variables.tf"
check_file "terraform/environments/prod/outputs.tf"

echo ""
echo "🚀 CI/CD:"
check_dir ".github/workflows"
check_file ".github/workflows/test.yml"
check_file ".github/workflows/build.yml"
check_file ".github/workflows/deploy.yml"

echo ""
echo "📜 Scripts:"
check_dir "scripts"
check_file "scripts/backup.sh"
check_file "scripts/restore.sh"
check_file "scripts/healthcheck.sh"

echo ""
echo "📊 Monitoring:"
check_dir "monitoring/dashboards"
check_file "monitoring/dashboards/service-overview.json"
check_dir "monitoring/alerts"
check_file "monitoring/alerts/alert-policies.md"

echo ""
echo "📚 Documentation:"
check_dir "docs"
check_file "docs/architecture.md"
check_file "docs/deployment.md"
check_file "docs/failure-scenarios.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "Keystone repository is complete and ready to use."
else
    echo -e "${RED}✗ Found $ERRORS missing files/directories${NC}"
    echo "Please review the setup."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
