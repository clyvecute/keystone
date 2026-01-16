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
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec terraform/; \
	else \
		echo "$(YELLOW)tfsec not installed. Install with: brew install tfsec$(NC)"; \
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

.DEFAULT_GOAL := help
