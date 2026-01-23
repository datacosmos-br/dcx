#===============================================================================
# Makefile - dc-scripts Development Lifecycle
#===============================================================================
# Targets:
#   Development: lint, test, check, validate
#   Versioning:  version-patch, version-minor, version-major
#   Release:     release, publish
#   Install:     install, uninstall, upgrade
#===============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Project
NAME := dc-scripts
REPO := datacosmos-br/dc-scripts
VERSION_FILE := VERSION
VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "0.0.0")

# Paths
PREFIX := /usr/local
INSTALL_DIR := $(PREFIX)/share/$(NAME)
BIN_DIR := $(PREFIX)/bin
CONFIG_DIR := $(HOME)/.config/$(NAME)

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
CYAN := \033[0;36m
NC := \033[0m

#===============================================================================
# Help
#===============================================================================
.PHONY: help
help: ## Show this help
	@echo ""
	@echo "$(CYAN)$(NAME) v$(VERSION)$(NC) - Oracle Automation Scripts"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(lint|test|check|validate|clean)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Versioning:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E 'version' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Release:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(release|publish|changelog)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Installation:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(install|uninstall|upgrade)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Sync:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E 'sync' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

#===============================================================================
# Development
#===============================================================================
.PHONY: lint
lint: ## Run shellcheck on all scripts
	@echo "$(CYAN)[LINT]$(NC) Running shellcheck..."
	@find lib/ -name '*.sh' -exec shellcheck -x {} \; 2>/dev/null || true
	@shellcheck -x restore.sh migrate_v2.sh 2>/dev/null || true
	@echo "$(GREEN)[OK]$(NC) Lint complete"

.PHONY: syntax
syntax: ## Check bash syntax on all scripts
	@echo "$(CYAN)[SYNTAX]$(NC) Checking bash syntax..."
	@errors=0; \
	for f in lib/*.sh restore.sh migrate_v2.sh; do \
		if ! bash -n "$$f" 2>/dev/null; then \
			echo "$(RED)[FAIL]$(NC) $$f"; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	if [ $$errors -eq 0 ]; then \
		echo "$(GREEN)[OK]$(NC) All scripts have valid syntax"; \
	else \
		echo "$(RED)[FAIL]$(NC) $$errors scripts with syntax errors"; \
		exit 1; \
	fi

.PHONY: test
test: ## Run all tests
	@echo "$(CYAN)[TEST]$(NC) Running test suite..."
	@cd tests && ./run_all_tests.sh
	@echo "$(GREEN)[OK]$(NC) All tests passed"

.PHONY: test-quick
test-quick: ## Run quick syntax tests only
	@echo "$(CYAN)[TEST]$(NC) Running quick tests..."
	@cd tests && ./run_all_tests.sh --quick
	@echo "$(GREEN)[OK]$(NC) Quick tests passed"

.PHONY: check
check: syntax test ## Run syntax check and all tests
	@echo "$(GREEN)[OK]$(NC) All checks passed"

.PHONY: validate
validate: lint syntax test ## Full validation (lint + syntax + tests)
	@echo "$(GREEN)[OK]$(NC) Full validation passed"

.PHONY: clean
clean: ## Clean temporary files
	@echo "$(CYAN)[CLEAN]$(NC) Removing temporary files..."
	@find . -name '*.log' -delete 2>/dev/null || true
	@find . -name '*.tmp' -delete 2>/dev/null || true
	@find . -name '*~' -delete 2>/dev/null || true
	@find . -name '*.swp' -delete 2>/dev/null || true
	@echo "$(GREEN)[OK]$(NC) Clean complete"

#===============================================================================
# Versioning (Semantic Versioning)
#===============================================================================
$(VERSION_FILE):
	@echo "0.0.0" > $(VERSION_FILE)

.PHONY: version
version: ## Show current version
	@echo "$(NAME) v$(VERSION)"

.PHONY: version-patch
version-patch: validate ## Bump patch version (0.0.X)
	@echo "$(CYAN)[VERSION]$(NC) Bumping patch version..."
	@current=$(VERSION); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	new="$$major.$$minor.$$((patch + 1))"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "$(GREEN)[OK]$(NC) Version: $$current -> $$new"

.PHONY: version-minor
version-minor: validate ## Bump minor version (0.X.0)
	@echo "$(CYAN)[VERSION]$(NC) Bumping minor version..."
	@current=$(VERSION); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	new="$$major.$$((minor + 1)).0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "$(GREEN)[OK]$(NC) Version: $$current -> $$new"

.PHONY: version-major
version-major: validate ## Bump major version (X.0.0)
	@echo "$(CYAN)[VERSION]$(NC) Bumping major version..."
	@current=$(VERSION); \
	major=$$(echo $$current | cut -d. -f1); \
	new="$$((major + 1)).0.0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "$(GREEN)[OK]$(NC) Version: $$current -> $$new"

#===============================================================================
# Release & Publish
#===============================================================================
.PHONY: changelog
changelog: ## Generate changelog from git commits
	@echo "$(CYAN)[CHANGELOG]$(NC) Generating changelog..."
	@echo "# Changelog" > CHANGELOG.md
	@echo "" >> CHANGELOG.md
	@echo "## v$(VERSION) - $$(date +%Y-%m-%d)" >> CHANGELOG.md
	@echo "" >> CHANGELOG.md
	@git log --oneline --no-merges $$(git describe --tags --abbrev=0 2>/dev/null || echo "")..HEAD 2>/dev/null | \
		sed 's/^[a-f0-9]* /- /' >> CHANGELOG.md || echo "- Initial release" >> CHANGELOG.md
	@echo "" >> CHANGELOG.md
	@echo "$(GREEN)[OK]$(NC) Changelog generated"

.PHONY: release
release: validate changelog ## Create a new release (validate + changelog + commit + tag)
	@echo "$(CYAN)[RELEASE]$(NC) Creating release v$(VERSION)..."
	@git add VERSION CHANGELOG.md
	@git commit -m "Release v$(VERSION)" || true
	@git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	@echo "$(GREEN)[OK]$(NC) Release v$(VERSION) created"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  git push origin main --tags"
	@echo "  make publish"

.PHONY: publish
publish: ## Publish release to GitHub
	@echo "$(CYAN)[PUBLISH]$(NC) Publishing to GitHub..."
	@git push origin main --tags
	@echo "$(CYAN)[PUBLISH]$(NC) Creating GitHub release..."
	@gh release create "v$(VERSION)" \
		--title "v$(VERSION)" \
		--notes-file CHANGELOG.md \
		--latest
	@echo "$(GREEN)[OK]$(NC) Published v$(VERSION) to GitHub"
	@echo ""
	@echo "$(GREEN)Release URL:$(NC) https://github.com/$(REPO)/releases/tag/v$(VERSION)"

.PHONY: release-publish
release-publish: release publish ## Create and publish release in one step
	@echo "$(GREEN)[OK]$(NC) Release v$(VERSION) created and published"

#===============================================================================
# Installation
#===============================================================================
.PHONY: install
install: ## Install dc-scripts to system
	@echo "$(CYAN)[INSTALL]$(NC) Installing $(NAME) v$(VERSION)..."
	@mkdir -p $(INSTALL_DIR)
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(CONFIG_DIR)
	@cp -r lib $(INSTALL_DIR)/
	@cp -r tests $(INSTALL_DIR)/
	@cp -r examples $(INSTALL_DIR)/
	@cp -r docs $(INSTALL_DIR)/
	@cp restore.sh $(INSTALL_DIR)/
	@cp migrate_v2.sh $(INSTALL_DIR)/
	@cp VERSION $(INSTALL_DIR)/
	@chmod +x $(INSTALL_DIR)/restore.sh $(INSTALL_DIR)/migrate_v2.sh
	@ln -sf $(INSTALL_DIR)/restore.sh $(BIN_DIR)/dc-restore
	@ln -sf $(INSTALL_DIR)/migrate_v2.sh $(BIN_DIR)/dc-migrate
	@echo "$(VERSION)" > $(CONFIG_DIR)/version
	@echo "$(GREEN)[OK]$(NC) Installed to $(INSTALL_DIR)"
	@echo "$(GREEN)[OK]$(NC) Commands: dc-restore, dc-migrate"

.PHONY: uninstall
uninstall: ## Uninstall dc-scripts from system
	@echo "$(CYAN)[UNINSTALL]$(NC) Removing $(NAME)..."
	@rm -rf $(INSTALL_DIR)
	@rm -f $(BIN_DIR)/dc-restore $(BIN_DIR)/dc-migrate
	@echo "$(GREEN)[OK]$(NC) Uninstalled (config preserved in $(CONFIG_DIR))"

.PHONY: upgrade
upgrade: ## Upgrade to latest version from GitHub
	@echo "$(CYAN)[UPGRADE]$(NC) Checking for updates..."
	@curl -fsSL https://raw.githubusercontent.com/$(REPO)/main/install.sh | bash -s -- --upgrade

#===============================================================================
# Sync (for development)
#===============================================================================
.PHONY: sync
sync: ## Sync to remote server (if sync.sh exists)
	@if [ -f sync.sh ]; then \
		./sync.sh push; \
	else \
		echo "$(YELLOW)[SKIP]$(NC) sync.sh not found"; \
	fi

.PHONY: sync-logs
sync-logs: ## Pull logs from remote server
	@if [ -f sync.sh ]; then \
		./sync.sh pull-logs; \
	else \
		echo "$(YELLOW)[SKIP]$(NC) sync.sh not found"; \
	fi

#===============================================================================
# Git helpers
#===============================================================================
.PHONY: status
status: ## Show git status
	@git status --short

.PHONY: diff
diff: ## Show git diff
	@git diff --stat

.PHONY: commit
commit: validate ## Commit changes (runs validation first)
	@echo "$(CYAN)[COMMIT]$(NC) Staging changes..."
	@git add -A
	@git status --short
	@read -p "Commit message: " msg; \
	git commit -m "$$msg"
	@echo "$(GREEN)[OK]$(NC) Changes committed"

.PHONY: push
push: ## Push to GitHub
	@git push origin main
	@echo "$(GREEN)[OK]$(NC) Pushed to GitHub"
