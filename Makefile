# Makefile
# Main orchestration for microservices-demo testing workflow
#
# Usage:
#   make all              # Build, deploy, test, coverage (local mode)
#   make quick            # Fast iteration (use cache)
#   make test             # Run tests (local mode)
#   make test TEST_MODE=k8s  # Run tests in K8s Job mode
#   make clean            # Clean build artifacts
#   make help             # Show this help

.PHONY: all help clean

# Default target
.DEFAULT_GOAL := help

# Configuration
CLUSTER_NAME ?= microservices-demo
TEST_MODE ?= local
AUTO_APPROVE ?= 1
export CLUSTER_NAME TEST_MODE AUTO_APPROVE

# Include all sub-makefiles
include makefiles/docker.mk
include makefiles/cluster.mk
include makefiles/deploy.mk
include makefiles/test.mk
include makefiles/coverage.mk
include makefiles/proto.mk
include makefiles/port-forward.mk

##@ General

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "Configuration:"
	@echo "  CLUSTER_NAME=$(CLUSTER_NAME)"
	@echo "  TEST_MODE=$(TEST_MODE)"
	@echo "  AUTO_APPROVE=$(AUTO_APPROVE)"
	@echo ""
	@echo "Examples:"
	@echo "  make all                    # Full workflow (build → deploy → test → coverage)"
	@echo "  make quick                  # Fast iteration (skip rebuilds)"
	@echo "  make test TEST_MODE=k8s     # Run tests in K8s Job mode"
	@echo "  make clean-all              # Nuclear option (delete everything)"
	@echo ""

##@ Complete Workflows

all: build deploy test-local coverage ## Full workflow: build → deploy → test → coverage (local mode)
	@echo ""
	@echo "========================================"
	@echo "✓ Complete workflow finished!"
	@echo "========================================"

quick: cluster deploy test-local ## Quick iteration (reuse builds, fast deploy)
	@echo ""
	@echo "✓ Quick workflow complete"

full-ci: clean cluster-create build deploy test-k8s coverage-summary ## Full CI workflow (K8s test mode)
	@echo ""
	@echo "========================================"
	@echo "✓ CI workflow complete"
	@echo "========================================"

build: build-images ## Build all Docker images

rebuild: clean-images build ## Force rebuild all images

##@ Utilities

logs: ## Tail logs from all pods
	@kubectl logs -f -l app --all-containers=true --prefix=true --max-log-requests=20 || \
		kubectl logs --tail=100 --all-containers=true --prefix=true --selector=app

status: cluster-status deployment-status ## Show overall system status

shell: ## Open shell in a test pod
	@kubectl run -it --rm debug --image=busybox --restart=Never -- sh

##@ Cleanup

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf .build test-framework/generated test-framework/reports
	@echo "✓ Build artifacts cleaned"

clean-all: port-forward-stop cluster-delete clean clean-images clean-coverage ## Nuclear option: delete everything
	@echo ""
	@echo "========================================"
	@echo "✓ Complete cleanup finished"
	@echo "========================================"
