#===============================================================================
# Makefile - DCX
#===============================================================================
# Comandos organizados em 5 grupos:
#   Development: lint, test, check, validate, clean
#   Versioning:  version, bump-patch, bump-minor, bump-major
#   Release:     release, publish
#   Install:     install, uninstall, update
#   Binaries:    binaries, binaries-all
#===============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

#-------------------------------------------------------------------------------
# Project Constants (read from etc/project.yaml via yq)
#-------------------------------------------------------------------------------
# Detect yq: bundled first, then system
YQ := $(shell test -x bin/yq && echo bin/yq || (command -v yq >/dev/null 2>&1 && echo yq || echo ""))

# Read from YAML with fallbacks
ifneq ($(YQ),)
  NAME := $(shell $(YQ) -r '.project.name // "DCX"' etc/project.yaml 2>/dev/null || echo "DCX")
  REPO := $(shell $(YQ) -r '.project.repo // "datacosmos-br/dcx"' etc/project.yaml 2>/dev/null || echo "datacosmos-br/dcx")
else
  NAME := DCX
  REPO := datacosmos-br/dcx
endif

VERSION := $(shell cat VERSION 2>/dev/null || echo "0.0.0")

#-------------------------------------------------------------------------------
# Paths
#-------------------------------------------------------------------------------
PREFIX      := $(HOME)/.local
INSTALL_DIR := $(PREFIX)/share/$(NAME)
BIN_DIR     := bin
RELEASE_DIR := release

#-------------------------------------------------------------------------------
# Platform Detection
#-------------------------------------------------------------------------------
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
  ARCH := amd64
endif
ifeq ($(ARCH),aarch64)
  ARCH := arm64
endif
PLATFORM := $(OS)-$(ARCH)

#-------------------------------------------------------------------------------
# Cores (ANSI)
#-------------------------------------------------------------------------------
C_RED    := \033[31m
C_GREEN  := \033[32m
C_YELLOW := \033[33m
C_BLUE   := \033[34m
C_CYAN   := \033[36m
C_BOLD   := \033[1m
C_RESET  := \033[0m

# Shortcuts para output
OK   = @printf "$(C_GREEN)✓$(C_RESET) %s\n"
FAIL = @printf "$(C_RED)✗$(C_RESET) %s\n"
INFO = @printf "$(C_CYAN)→$(C_RESET) %s\n"
WARN = @printf "$(C_YELLOW)!$(C_RESET) %s\n"

#===============================================================================
# HELP
#===============================================================================
.PHONY: help
help:
	@echo ""
	@printf "$(C_BOLD)$(NAME) v$(VERSION) - Datacosmos Command eXecutor$(C_RESET)\n"
	@echo ""
	@printf "$(C_GREEN)Development$(C_RESET)\n"
	@printf "  $(C_CYAN)lint$(C_RESET)       Shellcheck nos scripts\n"
	@printf "  $(C_CYAN)test$(C_RESET)       Roda todos os testes\n"
	@printf "  $(C_CYAN)check$(C_RESET)      Syntax + testes\n"
	@printf "  $(C_CYAN)validate$(C_RESET)   Lint + syntax + testes (completo)\n"
	@printf "  $(C_CYAN)clean$(C_RESET)      Remove arquivos temporários\n"
	@echo ""
	@printf "$(C_GREEN)Versioning$(C_RESET)\n"
	@printf "  $(C_CYAN)version$(C_RESET)    Mostra versão atual\n"
	@printf "  $(C_CYAN)bump-patch$(C_RESET) Incrementa patch (0.0.X)\n"
	@printf "  $(C_CYAN)bump-minor$(C_RESET) Incrementa minor (0.X.0)\n"
	@printf "  $(C_CYAN)bump-major$(C_RESET) Incrementa major (X.0.0)\n"
	@echo ""
	@printf "$(C_GREEN)Release$(C_RESET)\n"
	@printf "  $(C_CYAN)release$(C_RESET)    Cria tarball para release\n"
	@printf "  $(C_CYAN)publish$(C_RESET)    Publica no GitHub Releases\n"
	@echo ""
	@printf "$(C_GREEN)Binaries$(C_RESET)\n"
	@printf "  $(C_CYAN)binaries$(C_RESET)      Baixa binários para plataforma atual ($(PLATFORM))\n"
	@printf "  $(C_CYAN)binaries-all$(C_RESET)  Baixa binários para todas plataformas\n"
	@printf "  $(C_CYAN)binaries-required$(C_RESET) Baixa apenas gum e yq\n"
	@echo ""
	@printf "$(C_GREEN)Install/Update$(C_RESET)\n"
	@printf "  $(C_CYAN)install$(C_RESET)    Instala versão de desenvolvimento\n"
	@printf "  $(C_CYAN)update$(C_RESET)     Atualiza para última versão estável\n"
	@printf "  $(C_CYAN)uninstall$(C_RESET)  Remove instalação\n"
	@echo ""

#===============================================================================
# DEVELOPMENT
#===============================================================================

.PHONY: lint
lint: ## Shellcheck
	$(INFO) "Rodando shellcheck..."
	@if command -v shellcheck &>/dev/null; then \
		errors=0; \
		for f in lib/*.sh; do \
			if ! shellcheck -x "$$f" 2>/dev/null; then \
				errors=$$((errors + 1)); \
			fi; \
		done; \
		if [ $$errors -eq 0 ]; then \
			printf "$(C_GREEN)✓$(C_RESET) Lint OK\n"; \
		else \
			printf "$(C_YELLOW)!$(C_RESET) $$errors arquivo(s) com warnings\n"; \
		fi; \
	else \
		printf "$(C_YELLOW)!$(C_RESET) shellcheck não instalado\n"; \
	fi

.PHONY: syntax
syntax: ## Syntax check
	$(INFO) "Verificando sintaxe bash..."
	@errors=0; \
	for f in lib/*.sh; do \
		if ! bash -n "$$f" 2>/dev/null; then \
			printf "$(C_RED)✗$(C_RESET) $$f\n"; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	if [ $$errors -eq 0 ]; then \
		printf "$(C_GREEN)✓$(C_RESET) Sintaxe OK\n"; \
	else \
		printf "$(C_RED)✗$(C_RESET) $$errors erro(s) de sintaxe\n"; \
		exit 1; \
	fi

.PHONY: test
test: ## Roda testes
	$(INFO) "Rodando testes..."
	@if [ -f tests/run_all_tests.sh ]; then \
		chmod +x tests/run_all_tests.sh tests/test_*.sh 2>/dev/null || true; \
		./tests/run_all_tests.sh; \
	else \
		printf "$(C_YELLOW)!$(C_RESET) tests/run_all_tests.sh não encontrado\n"; \
	fi

.PHONY: check
check: syntax test ## Syntax + testes
	$(OK) "Check completo"

.PHONY: validate
validate: lint syntax test ## Validação completa
	@echo ""
	$(OK) "Validação completa passou"

.PHONY: clean
clean: ## Limpa temporários
	$(INFO) "Limpando..."
	@rm -rf tests/tmp 2>/dev/null || true
	@find . -name '*.log' -delete 2>/dev/null || true
	@find . -name '*.tmp' -delete 2>/dev/null || true
	@find . -name '*~' -delete 2>/dev/null || true
	$(OK) "Limpo"

#===============================================================================
# VERSIONING
#===============================================================================

.PHONY: version
version: ## Mostra versão
	@echo "$(NAME) v$(VERSION)"

.PHONY: bump-patch
bump-patch: ## Bump patch (0.0.X)
	@current=$(VERSION); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	new="$$major.$$minor.$$((patch + 1))"; \
	echo "$$new" > VERSION; \
	printf "$(C_GREEN)✓$(C_RESET) $$current → $$new\n"

.PHONY: bump-minor
bump-minor: ## Bump minor (0.X.0)
	@current=$(VERSION); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	new="$$major.$$((minor + 1)).0"; \
	echo "$$new" > VERSION; \
	printf "$(C_GREEN)✓$(C_RESET) $$current → $$new\n"

.PHONY: bump-major
bump-major: ## Bump major (X.0.0)
	@current=$(VERSION); \
	major=$$(echo $$current | cut -d. -f1); \
	new="$$((major + 1)).0.0"; \
	echo "$$new" > VERSION; \
	printf "$(C_GREEN)✓$(C_RESET) $$current → $$new\n"

#===============================================================================
# RELEASE
#===============================================================================

.PHONY: changelog
changelog: ## Gera changelog
	$(INFO) "Gerando CHANGELOG.md..."
	@echo "# Changelog" > CHANGELOG.md
	@echo "" >> CHANGELOG.md
	@echo "## v$(VERSION) - $$(date +%Y-%m-%d)" >> CHANGELOG.md
	@echo "" >> CHANGELOG.md
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		last_tag=$$(git describe --tags --abbrev=0 2>/dev/null || echo ""); \
		if [ -n "$$last_tag" ]; then \
			git log --oneline --no-merges "$$last_tag..HEAD" 2>/dev/null | \
				sed 's/^[a-f0-9]* /- /' >> CHANGELOG.md; \
		else \
			git log --oneline --no-merges -20 2>/dev/null | \
				sed 's/^[a-f0-9]* /- /' >> CHANGELOG.md; \
		fi; \
	else \
		echo "- Initial release" >> CHANGELOG.md; \
	fi
	$(OK) "CHANGELOG.md gerado"

.PHONY: release
release: validate changelog ## Cria release tarball
	$(INFO) "Criando release v$(VERSION)..."
	@mkdir -p $(RELEASE_DIR)
	@tar -czf $(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz \
		--transform 's,^,$(NAME)-$(VERSION)/,' \
		--exclude='release' \
		--exclude='.git' \
		--exclude='*.tar.gz' \
		--exclude='build' \
		--exclude='bin/dcx-go' \
		lib/ etc/ plugins/ share/ tests/ bin/ \
		VERSION README.md Makefile install.sh \
		2>/dev/null
	@cd $(RELEASE_DIR) && sha256sum $(NAME)-$(VERSION).tar.gz > $(NAME)-$(VERSION).sha256
	$(OK) "$(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz"
	@ls -lh $(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz

.PHONY: publish
publish: ## Publica no GitHub
	$(INFO) "Publicando v$(VERSION) no GitHub..."
	@if [ ! -f "$(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz" ]; then \
		printf "$(C_RED)✗$(C_RESET) Tarball não encontrado. Rode: make release\n"; \
		exit 1; \
	fi
	@if ! command -v gh &>/dev/null; then \
		printf "$(C_RED)✗$(C_RESET) gh CLI não instalado\n"; \
		exit 1; \
	fi
	@git add VERSION CHANGELOG.md
	@git commit -m "Release v$(VERSION)" 2>/dev/null || true
	@git tag -a "v$(VERSION)" -m "Release v$(VERSION)" 2>/dev/null || \
		printf "$(C_YELLOW)!$(C_RESET) Tag já existe\n"
	@git push origin main --tags 2>/dev/null || true
	@gh release create "v$(VERSION)" \
		--title "v$(VERSION)" \
		--notes-file CHANGELOG.md \
		$(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz \
		$(RELEASE_DIR)/$(NAME)-$(VERSION).sha256
	$(OK) "Publicado: https://github.com/$(REPO)/releases/tag/v$(VERSION)"

.PHONY: deploy
deploy: ## Commit, build, release e publish em um comando
	$(INFO) "Deploy completo v$(VERSION)..."
	@# 1. Commit all changes
	@git add -A
	@git diff --cached --quiet || git commit -m "feat: Release v$(VERSION)" || true
	@# 2. Push to remote
	@git push origin main 2>/dev/null || true
	@# 3. Build Go binaries
	$(INFO) "Compilando binários..."
	@./scripts/build.sh all
	@# 4. Run tests
	$(INFO) "Rodando testes..."
	@bash tests/run_all_tests.sh >/dev/null && $(OK) "Testes OK" || { $(WARN) "Testes falharam"; exit 1; }
	@# 5. Create release tarball
	$(INFO) "Criando release..."
	@mkdir -p $(RELEASE_DIR)
	@tar -czf $(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz \
		--transform 's,^,$(NAME)-$(VERSION)/,' \
		--exclude='release' \
		--exclude='.git' \
		--exclude='*.tar.gz' \
		--exclude='build' \
		--exclude='bin/dcx-go' \
		lib/ etc/ plugins/ share/ tests/ bin/ \
		VERSION README.md Makefile install.sh \
		2>/dev/null
	@cd $(RELEASE_DIR) && sha256sum $(NAME)-$(VERSION).tar.gz > $(NAME)-$(VERSION).sha256
	@# 6. Upload to GitHub Release (update if exists)
	$(INFO) "Atualizando GitHub Release..."
	@gh release upload "v$(VERSION)" \
		$(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz \
		$(RELEASE_DIR)/$(NAME)-$(VERSION).sha256 \
		--clobber 2>/dev/null || \
		gh release create "v$(VERSION)" \
			--title "v$(VERSION)" \
			--notes "Release v$(VERSION)" \
			$(RELEASE_DIR)/$(NAME)-$(VERSION).tar.gz \
			$(RELEASE_DIR)/$(NAME)-$(VERSION).sha256
	$(OK) "Deploy completo: https://github.com/$(REPO)/releases/tag/v$(VERSION)"

#===============================================================================
# BINARIES
#===============================================================================

.PHONY: binaries
binaries: ## Baixa binários para plataforma atual
	$(INFO) "Baixando binários para $(PLATFORM)..."
	@./scripts/build-binaries.sh all
	$(OK) "Binários instalados em $(BIN_DIR)/"

.PHONY: binaries-all
binaries-all: ## Baixa binários para todas plataformas
	$(INFO) "Baixando binários para todas plataformas..."
	@./scripts/build-binaries.sh --all-platforms all
	$(OK) "Binários instalados"

.PHONY: binaries-required
binaries-required: ## Baixa apenas gum e yq
	$(INFO) "Baixando gum e yq para $(PLATFORM)..."
	@./scripts/build-binaries.sh required
	$(OK) "Binários essenciais instalados"

.PHONY: binaries-check
binaries-check: ## Verifica binários presentes
	@./scripts/build-binaries.sh check

#===============================================================================
# INSTALL
#===============================================================================

.PHONY: install
install: ## Instala versão de desenvolvimento em ~/.local
	$(INFO) "Instalando $(NAME) v$(VERSION) (desenvolvimento)..."
	@mkdir -p $(INSTALL_DIR)/{lib,etc,bin,plugins,share/completions}
	@mkdir -p $(PREFIX)/bin
	@# Copia arquivos
	@cp -r lib/* $(INSTALL_DIR)/lib/ 2>/dev/null || true
	@cp -r etc/* $(INSTALL_DIR)/etc/ 2>/dev/null || true
	@cp VERSION $(INSTALL_DIR)/ 2>/dev/null || true
	@# Copia binários (se existirem)
	@for tool in gum yq rg fd sd; do \
		if [ -f "$(BIN_DIR)/$${tool}-$(PLATFORM)" ]; then \
			cp "$(BIN_DIR)/$${tool}-$(PLATFORM)" "$(INSTALL_DIR)/bin/"; \
			ln -sf "$${tool}-$(PLATFORM)" "$(INSTALL_DIR)/bin/$${tool}"; \
		elif [ -f "$(BIN_DIR)/$${tool}" ]; then \
			cp "$(BIN_DIR)/$${tool}" "$(INSTALL_DIR)/bin/"; \
		fi; \
	done
	@# Copia completions
	@cp -r bin/completions $(INSTALL_DIR)/bin/ 2>/dev/null || true
	@# Copia dcx para PATH
	@cp bin/dcx $(PREFIX)/bin/dcx
	@chmod +x $(PREFIX)/bin/dcx
	@# Configura DC_HOME
	@sed -i "s|DC_HOME=.*|DC_HOME=\"$(INSTALL_DIR)\"|" $(PREFIX)/bin/dcx 2>/dev/null || true
	$(OK) "Instalado em $(INSTALL_DIR)"
	@echo ""
	@printf "  Adicione ao seu ~/.bashrc ou ~/.zshrc:\n"
	@printf "    $(C_CYAN)export PATH=\"$(PREFIX)/bin:\$$PATH\"$(C_RESET)\n"
	@printf "    $(C_CYAN)source $(INSTALL_DIR)/bin/completions/dcx.bash$(C_RESET)\n"

.PHONY: update
update: ## Atualiza instalação atual para última versão
	$(INFO) "Atualizando $(NAME)..."
	@bash -c 'source lib/constants.sh && source lib/update.sh && dc_self_update'
	$(OK) "Atualização concluída"
	@echo ""

.PHONY: uninstall
uninstall: ## Remove instalação
	$(INFO) "Removendo $(NAME)..."
	@rm -rf $(INSTALL_DIR)
	@rm -f $(PREFIX)/bin/dcx
	$(OK) "Removido"

#===============================================================================
# DEPS (para desenvolvimento)
#===============================================================================

.PHONY: deps
deps: ## Verifica dependências
	$(INFO) "Verificando dependências..."
	@missing=0; \
	for cmd in bash gum yq shellcheck; do \
		if command -v $$cmd &>/dev/null; then \
			printf "  $(C_GREEN)✓$(C_RESET) $$cmd\n"; \
		else \
			printf "  $(C_RED)✗$(C_RESET) $$cmd\n"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo ""; \
		printf "$(C_YELLOW)!$(C_RESET) Dependências faltando\n"; \
	else \
		printf "$(C_GREEN)✓$(C_RESET) Todas dependências OK\n"; \
	fi

#===============================================================================
# INTERNAL
#===============================================================================

.PHONY: distclean
distclean: clean ## Limpa tudo (incluindo releases)
	$(INFO) "Limpando releases..."
	@rm -rf $(RELEASE_DIR)
	@rm -rf build
	$(OK) "Distclean completo"
