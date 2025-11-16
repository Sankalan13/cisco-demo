# cluster.mk
# Kind cluster lifecycle management

# Configuration
CLUSTER_NAME := microservices-demo
CLUSTER_CONTEXT := kind-$(CLUSTER_NAME)
AUTO_APPROVE ?= 1

##@ Cluster Management

.PHONY: cluster cluster-create cluster-delete cluster-status cluster-exists

cluster: cluster-create ## Create Kind cluster (alias)

cluster-create: .build/cluster-created ## Create Kind cluster if it doesn't exist

.build/cluster-created:
	@echo "Checking for existing Kind cluster..."
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "✓ Cluster '$(CLUSTER_NAME)' already exists"; \
		if [ "$(AUTO_APPROVE)" != "1" ]; then \
			read -p "Delete and recreate cluster? (y/n): " -n 1 -r REPLY; \
			echo; \
			if echo $$REPLY | grep -iq "^y$$"; then \
				kind delete cluster --name $(CLUSTER_NAME); \
				kind create cluster --name $(CLUSTER_NAME); \
				echo "✓ Cluster recreated"; \
			fi; \
		else \
			echo "Using existing cluster (AUTO_APPROVE=1)"; \
		fi; \
	else \
		echo "Creating Kind cluster '$(CLUSTER_NAME)'..."; \
		kind create cluster --name $(CLUSTER_NAME); \
		echo "✓ Cluster created"; \
	fi
	@kubectl config use-context $(CLUSTER_CONTEXT) > /dev/null 2>&1
	@mkdir -p .build && touch $@

cluster-delete: ## Delete Kind cluster
	@echo "Deleting Kind cluster '$(CLUSTER_NAME)'..."
	@kind delete cluster --name $(CLUSTER_NAME) || true
	@rm -f .build/cluster-created .build/images-loaded .build/deployed
	@echo "✓ Cluster deleted"

cluster-status: ## Show cluster status
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Context: $(CLUSTER_CONTEXT)"
	@kubectl cluster-info --context $(CLUSTER_CONTEXT) 2>/dev/null || echo "Cluster not accessible"
	@echo ""
	@kubectl get nodes 2>/dev/null || echo "No nodes found"

cluster-exists: ## Check if cluster exists
	@kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$" && echo "Cluster exists" || echo "Cluster does not exist"
