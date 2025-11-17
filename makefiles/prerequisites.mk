# makefiles/prerequisites.mk
# Prerequisites installation for microservices-demo testing framework
#
# Tested on:
#   - macOS v15.6.1
#   - Ubuntu Server 24.04.2 LTS
#
# Usage:
#   make install-prereqs        # Install all prerequisites
#   make check-prereqs          # Check which prerequisites are installed
#   make install-homebrew       # Install only Homebrew
#   make install-python         # Install only Python toolchain
#   make install-docker         # Install only Docker
#   make install-k8s-tools      # Install only Kubernetes tools

.PHONY: install-prereqs check-prereqs

# Detect OS
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    OS := macos
else ifeq ($(UNAME_S),Linux)
    OS := linux
else
    OS := unknown
endif

# Python version required
PYTHON_VERSION := 3.12.11
PYTHON_VERSION_FILE := test-framework/.python-version

##@ Prerequisites

install-prereqs: check-os install-homebrew install-pyenv install-python-deps install-python install-docker install-k8s-tools install-netcat ## Install all prerequisites
	@echo ""
	@echo "========================================"
	@echo "✓ All prerequisites installed!"
	@echo "========================================"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Restart your terminal or run: source ~/.zprofile (zsh) or source ~/.bashrc (bash)"
	@echo "  2. Verify Python version: python -V"
	@echo "  3. Login to Docker: docker login"
	@echo "  4. Run: make check-prereqs"
	@echo ""

check-prereqs: ## Check which prerequisites are installed
	@echo "Checking prerequisites..."
	@echo ""
	@echo "Operating System: $(OS)"
	@echo ""
	@printf "%-20s" "Homebrew:"
	@command -v brew >/dev/null 2>&1 && echo "✓ Installed ($(shell brew --version | head -1))" || echo "✗ Not installed"
	@printf "%-20s" "pyenv:"
	@command -v pyenv >/dev/null 2>&1 && echo "✓ Installed ($(shell pyenv --version))" || echo "✗ Not installed"
	@printf "%-20s" "Python $(PYTHON_VERSION):"
	@python -V 2>&1 | grep -q "$(PYTHON_VERSION)" && echo "✓ Active" || (command -v python >/dev/null 2>&1 && echo "⚠ Installed ($(shell python -V 2>&1)) but wrong version" || echo "✗ Not installed")
	@printf "%-20s" "Docker:"
	@command -v docker >/dev/null 2>&1 && echo "✓ Installed ($(shell docker --version))" || echo "✗ Not installed"
	@printf "%-20s" "kubectl:"
	@command -v kubectl >/dev/null 2>&1 && echo "✓ Installed ($(shell kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1))" || echo "✗ Not installed"
	@printf "%-20s" "kind:"
	@command -v kind >/dev/null 2>&1 && echo "✓ Installed ($(shell kind --version))" || echo "✗ Not installed"
	@printf "%-20s" "netcat:"
	@command -v nc >/dev/null 2>&1 && echo "✓ Installed" || echo "✗ Not installed"
	@echo ""

check-os: ## Check if OS is supported
	@if [ "$(OS)" = "unknown" ]; then \
		echo "Error: Unsupported operating system"; \
		echo "This makefile supports macOS and Linux only"; \
		exit 1; \
	fi
	@echo "✓ Detected OS: $(OS)"

##@ Homebrew Installation

install-homebrew: ## Install Homebrew (macOS/Linux)
	@if command -v brew >/dev/null 2>&1; then \
		echo "✓ Homebrew already installed"; \
	else \
		echo "Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		if [ "$(OS)" = "linux" ]; then \
			echo "Adding Homebrew to PATH for Linux..."; \
			echo 'eval "$$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc; \
			eval "$$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; \
		fi; \
		echo "✓ Homebrew installed"; \
	fi

##@ Python Installation

install-pyenv: install-homebrew ## Install pyenv
	@if command -v pyenv >/dev/null 2>&1; then \
		echo "✓ pyenv already installed"; \
	else \
		echo "Installing pyenv..."; \
		brew install pyenv; \
		echo "Configuring pyenv in shell..."; \
		if [ -f ~/.zprofile ]; then \
			echo 'export PYENV_ROOT="$$HOME/.pyenv"' >> ~/.zprofile; \
			echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"' >> ~/.zprofile; \
			echo 'eval "$$(pyenv init -)"' >> ~/.zprofile; \
			echo "✓ pyenv configured in ~/.zprofile"; \
		elif [ -f ~/.bash_profile ]; then \
			echo 'export PYENV_ROOT="$$HOME/.pyenv"' >> ~/.bash_profile; \
			echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"' >> ~/.bash_profile; \
			echo 'eval "$$(pyenv init -)"' >> ~/.bash_profile; \
			echo "✓ pyenv configured in ~/.bash_profile"; \
		else \
			echo 'export PYENV_ROOT="$$HOME/.pyenv"' >> ~/.bashrc; \
			echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"' >> ~/.bashrc; \
			echo 'eval "$$(pyenv init -)"' >> ~/.bashrc; \
			echo "✓ pyenv configured in ~/.bashrc"; \
		fi; \
		export PYENV_ROOT="$$HOME/.pyenv"; \
		export PATH="$$PYENV_ROOT/bin:$$PATH"; \
		eval "$$(pyenv init -)"; \
		echo "✓ pyenv installed"; \
	fi

install-python-deps: install-homebrew ## Install Python build dependencies
	@echo "Installing Python build dependencies..."
	@if [ "$(OS)" = "macos" ]; then \
		brew install openssl readline sqlite3 xz zlib; \
	else \
		echo "Note: On Linux, you may need to install build dependencies manually:"; \
		echo "  Ubuntu/Debian: sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \\"; \
		echo "                 libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \\"; \
		echo "                 libncurses5-dev libncursesw5-dev xz-utils tk-dev \\"; \
		echo "                 libffi-dev liblzma-dev python3-openssl git"; \
	fi
	@echo "✓ Python dependencies installed"

install-python: install-pyenv install-python-deps ## Install Python $(PYTHON_VERSION)
	@export PYENV_ROOT="$$HOME/.pyenv"; \
	export PATH="$$PYENV_ROOT/bin:$$PATH"; \
	eval "$$(pyenv init -)"; \
	if pyenv versions | grep -q "$(PYTHON_VERSION)"; then \
		echo "✓ Python $(PYTHON_VERSION) already installed"; \
	else \
		echo "Installing Python $(PYTHON_VERSION)..."; \
		pyenv install $(PYTHON_VERSION); \
		echo "✓ Python $(PYTHON_VERSION) installed"; \
	fi; \
	if [ -f "$(PYTHON_VERSION_FILE)" ]; then \
		cd $$(dirname $(PYTHON_VERSION_FILE)) && pyenv local $(PYTHON_VERSION); \
	else \
		pyenv local $(PYTHON_VERSION); \
	fi; \
	echo "✓ Python $(PYTHON_VERSION) set as local version"; \
	python -V

##@ Docker Installation

install-docker: ## Install Docker
	@if command -v docker >/dev/null 2>&1; then \
		echo "✓ Docker already installed"; \
		echo "Note: Make sure Docker Desktop is running"; \
	else \
		echo "Installing Docker..."; \
		if [ "$(OS)" = "macos" ]; then \
			echo ""; \
			echo "=================================================="; \
			echo "Docker Desktop must be installed manually on macOS"; \
			echo "=================================================="; \
			echo ""; \
			echo "Please visit: https://docs.docker.com/desktop/setup/install/mac-install/"; \
			echo ""; \
			echo "After installation:"; \
			echo "  1. Start Docker Desktop"; \
			echo "  2. Run: docker login"; \
			echo "  3. Run: make check-prereqs"; \
			echo ""; \
			exit 1; \
		else \
			echo "On Linux, install Docker using your package manager:"; \
			echo "  Ubuntu: https://docs.docker.com/engine/install/ubuntu/"; \
			echo "  Other: https://docs.docker.com/engine/install/"; \
		fi; \
	fi

docker-login: ## Login to Docker (required for private registries)
	@echo "Logging into Docker..."
	@echo "Note: You'll need credentials to access us-central1-docker.pkg.dev/google-samples/microservices-demo"
	@docker login

##@ Kubernetes Tools Installation

install-k8s-tools: install-kubectl install-kind ## Install all Kubernetes tools

install-kubectl: install-homebrew ## Install kubectl
	@if command -v kubectl >/dev/null 2>&1; then \
		echo "✓ kubectl already installed"; \
	else \
		echo "Installing kubectl..."; \
		if [ "$(OS)" = "macos" ]; then \
			brew install kubectl; \
		else \
			brew install kubectl || ( \
				echo "Installing kubectl via curl..."; \
				curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
				chmod +x kubectl; \
				sudo mv kubectl /usr/local/bin/; \
			); \
		fi; \
		echo "✓ kubectl installed"; \
	fi

install-kind: install-homebrew ## Install kind
	@if command -v kind >/dev/null 2>&1; then \
		echo "✓ kind already installed"; \
	else \
		echo "Installing kind..."; \
		brew install kind; \
		echo "✓ kind installed"; \
	fi

##@ Utilities Installation

install-netcat: ## Install netcat
	@if command -v nc >/dev/null 2>&1; then \
		echo "✓ netcat already installed"; \
	else \
		echo "Installing netcat..."; \
		if [ "$(OS)" = "macos" ]; then \
			brew install netcat; \
		else \
			echo "On Linux, install netcat using your package manager:"; \
			echo "  Ubuntu/Debian: sudo apt-get install netcat"; \
			echo "  RHEL/Fedora: sudo dnf install nc"; \
		fi; \
		echo "✓ netcat installed"; \
	fi

##@ Troubleshooting

fix-pyenv-path: ## Fix pyenv PATH configuration
	@echo "Fixing pyenv PATH configuration..."
	@if [ -f ~/.zprofile ]; then \
		grep -q 'PYENV_ROOT' ~/.zprofile || ( \
			echo 'export PYENV_ROOT="$$HOME/.pyenv"' >> ~/.zprofile; \
			echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"' >> ~/.zprofile; \
			echo 'eval "$$(pyenv init -)"' >> ~/.zprofile; \
		); \
		source ~/.zprofile; \
		echo "✓ Fixed in ~/.zprofile"; \
	elif [ -f ~/.bash_profile ]; then \
		grep -q 'PYENV_ROOT' ~/.bash_profile || ( \
			echo 'export PYENV_ROOT="$$HOME/.pyenv"' >> ~/.bash_profile; \
			echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"' >> ~/.bash_profile; \
			echo 'eval "$$(pyenv init -)"' >> ~/.bash_profile; \
		); \
		source ~/.bash_profile; \
		echo "✓ Fixed in ~/.bash_profile"; \
	else \
		grep -q 'PYENV_ROOT' ~/.bashrc || ( \
			echo 'export PYENV_ROOT="$$HOME/.pyenv"' >> ~/.bashrc; \
			echo '[[ -d $$PYENV_ROOT/bin ]] && export PATH="$$PYENV_ROOT/bin:$$PATH"' >> ~/.bashrc; \
			echo 'eval "$$(pyenv init -)"' >> ~/.bashrc; \
		); \
		source ~/.bashrc; \
		echo "✓ Fixed in ~/.bashrc"; \
	fi
	@echo "Please restart your terminal or run: source ~/.zprofile (or ~/.bashrc)"

fix-python-version: ## Set Python version to $(PYTHON_VERSION)
	@export PYENV_ROOT="$$HOME/.pyenv"; \
	export PATH="$$PYENV_ROOT/bin:$$PATH"; \
	eval "$$(pyenv init -)"; \
	if [ -f "$(PYTHON_VERSION_FILE)" ]; then \
		cd $$(dirname $(PYTHON_VERSION_FILE)) && pyenv local $(PYTHON_VERSION); \
	else \
		pyenv local $(PYTHON_VERSION); \
	fi; \
	echo "✓ Python version set to $(PYTHON_VERSION)"; \
	python -V
