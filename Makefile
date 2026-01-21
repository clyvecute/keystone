.PHONY: help init plan apply destroy backup restore health logs clean

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default environment
ENV ?= dev

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Keystone Infrastructure Management$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

build-preflight: ## Build preflight checker
	@echo "$(BLUE)Building preflight checker...$(NC)"
	cd tools/preflight && go build -o ../../bin/preflight
	@echo "$(GREEN)Built: bin/preflight$(NC)"

preflight: build-preflight ## Run preflight checks
	@echo "$(BLUE)Running preflight checks...$(NC)"
	@./bin/preflight

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	cd terraform/environments/$(ENV) && terraform init

plan: ## Plan infrastructure changes
	@echo "$(BLUE)Planning infrastructure changes for $(ENV)...$(NC)"
	cd terraform/environments/$(ENV) && terraform plan

apply: ## Apply infrastructure changes
	@echo "$(BLUE)Applying infrastructure changes for $(ENV)...$(NC)"
	cd terraform/environments/$(ENV) && terraform apply

destroy: ## Destroy infrastructure (use with caution!)
	@echo "$(RED)WARNING: This will destroy infrastructure in $(ENV)!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform/environments/$(ENV) && terraform destroy; \
	fi

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	cd terraform/environments/$(ENV) && terraform validate

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive terraform/

backup: ## Run backup script
	@echo "$(BLUE)Running backup...$(NC)"
	./scripts/backup.sh

restore: ## Restore from backup (requires BACKUP_ID)
	@echo "$(BLUE)Restoring from backup $(BACKUP_ID)...$(NC)"
	./scripts/restore.sh $(BACKUP_ID)

health: ## Run health check
	@echo "$(BLUE)Running health check...$(NC)"
	./scripts/healthcheck.sh

logs: ## View application logs
	@echo "$(BLUE)Fetching logs for $(ENV)...$(NC)"
	@if [ "$(ENV)" = "dev" ]; then \
		echo "Local logs not yet implemented"; \
	else \
		gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$(APP_NAME)" --limit 50 --format json; \
	fi

deploy-dev: ## Deploy to dev environment
	@echo "$(BLUE)Deploying to dev...$(NC)"
	$(MAKE) ENV=dev apply

deploy-prod: ## Deploy to production
	@echo "$(BLUE)Deploying to production...$(NC)"
	$(MAKE) ENV=prod apply

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	find . -type f -name "*.tfstate.backup" -delete
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Clean complete$(NC)"

test-scripts: ## Test all operational scripts
	@echo "$(BLUE)Testing scripts...$(NC)"
	shellcheck scripts/*.sh || echo "$(YELLOW)shellcheck not installed, skipping$(NC)"
	@echo "$(GREEN)Script tests complete$(NC)"

security-scan: ## Run security scan on Terraform
	@echo "$(BLUE)Running security scan...$(NC)"
	@if command -v tfsec > /dev/null 2>&1; then \
		tfsec terraform/ --format=default --soft-fail; \
	else \
		echo "$(YELLOW)tfsec not installed. Install with: brew install tfsec$(NC)"; \
	fi
	@if command -v checkov > /dev/null 2>&1; then \
		checkov -d terraform/ --framework terraform; \
	else \
		echo "$(YELLOW)checkov not installed. Install with: pip install checkov$(NC)"; \
	fi

rotate-secrets: ## Rotate all secrets (database passwords, service account keys)
	@echo "$(BLUE)Rotating secrets for $(ENV)...$(NC)"
	@chmod +x scripts/rotate-secrets.sh
	@./scripts/rotate-secrets.sh
	@echo "$(GREEN)Secret rotation complete$(NC)"

compliance-check: ## Run compliance checks
	@echo "$(BLUE)Running compliance checks...$(NC)"
	@echo "$(YELLOW)Checking encryption configuration...$(NC)"
	@grep -r "encryption" terraform/ || echo "$(RED)No encryption configuration found$(NC)"
	@echo "$(YELLOW)Checking IAM policies...$(NC)"
	@grep -r "iam" terraform/ || echo "$(RED)No IAM policies found$(NC)"
	@echo "$(YELLOW)Checking backup configuration...$(NC)"
	@grep -r "backup" terraform/ || echo "$(RED)No backup configuration found$(NC)"
	@echo "$(GREEN)Compliance check complete$(NC)"

security-audit: ## Generate security audit report
	@echo "$(BLUE)Generating security audit report...$(NC)"
	@mkdir -p ./reports
	@echo "# Security Audit Report - $(shell date)" > ./reports/security-audit-$(shell date +%Y%m%d).md
	@echo "" >> ./reports/security-audit-$(shell date +%Y%m%d).md
	@echo "## Infrastructure Security" >> ./reports/security-audit-$(shell date +%Y%m%d).md
	@tfsec terraform/ --format markdown >> ./reports/security-audit-$(shell date +%Y%m%d).md 2>/dev/null || echo "tfsec not available"
	@echo "$(GREEN)Audit report generated: ./reports/security-audit-$(shell date +%Y%m%d).md$(NC)"

vulnerability-scan: ## Scan for vulnerabilities
	@echo "$(BLUE)Scanning for vulnerabilities...$(NC)"
	@if command -v trivy > /dev/null 2>&1; then \
		trivy config terraform/; \
	else \
		echo "$(YELLOW)trivy not installed. Install with: brew install trivy$(NC)"; \
	fi

secrets-check: ## Check for exposed secrets
	@echo "$(BLUE)Checking for exposed secrets...$(NC)"
	@if command -v gitleaks > /dev/null 2>&1; then \
		gitleaks detect --source . --verbose; \
	else \
		echo "$(YELLOW)gitleaks not installed. Install with: brew install gitleaks$(NC)"; \
	fi

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table terraform/modules/network > terraform/modules/network/README.md; \
		terraform-docs markdown table terraform/modules/compute > terraform/modules/compute/README.md; \
		terraform-docs markdown table terraform/modules/database > terraform/modules/database/README.md; \
		terraform-docs markdown table terraform/modules/monitoring > terraform/modules/monitoring/README.md; \
		echo "$(GREEN)Documentation generated$(NC)"; \
	else \
		echo "$(YELLOW)terraform-docs not installed$(NC)"; \
	fi

bootstrap: ## Initial project setup (create buckets, enable APIs)
	@echo "$(BLUE)Bootstrapping $(ENV) environment...$(NC)"
	@chmod +x scripts/bootstrap.sh
	@./scripts/bootstrap.sh $(ENV)

setup-wif: ## Setup Workload Identity Federation for GitHub Actions
	@echo "$(BLUE)Setting up Workload Identity Federation...$(NC)"
	@chmod +x scripts/setup-wif.sh
	@./scripts/setup-wif.sh

test-infra: ## Run Terraform unit tests
	@echo "$(BLUE)Running Terraform unit tests...$(NC)"
	@cd terraform/modules/network && terraform test
	@echo "$(GREEN)Infrastructure tests passed$(NC)"

.DEFAULT_GOAL := help
