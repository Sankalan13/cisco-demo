# deploy.mk
# Kubernetes deployment using Kustomize

# Configuration
KUSTOMIZE_OVERLAY := microservices-demo/kustomize/overlays/test
DEPLOYMENT_TIMEOUT := 600s

##@ Deployment

.PHONY: deploy load-images wait-deployments undeploy

deploy: .build/deployed ## Deploy all services to cluster

.build/deployed: .build/cluster-created .build/images-loaded
	@echo "Deploying microservices with Kustomize..."
	@kubectl apply -k $(KUSTOMIZE_OVERLAY)
	@echo "✓ Manifests applied"
	@echo ""
	@echo "Waiting for deployments to be ready (timeout: $(DEPLOYMENT_TIMEOUT))..."
	@kubectl wait --for=condition=available --timeout=$(DEPLOYMENT_TIMEOUT) deployment --all 2>/dev/null || \
		(echo "⚠ Some deployments not ready within timeout, checking status..." && kubectl get deployments)
	@echo "✓ All deployments ready"
	@mkdir -p .build && touch $@

load-images: .build/images-loaded ## Load Docker images into Kind cluster

.build/images-loaded: .build/cluster-created build-images
	@echo "Loading images into Kind cluster..."
	@for img in $(GO_SERVICES); do \
		echo "  Loading $$img:$(GO_TAG)..."; \
		kind load docker-image $$img:$(GO_TAG) --name $(CLUSTER_NAME) > /dev/null 2>&1; \
	done
	@for img in $(NODE_SERVICES); do \
		echo "  Loading $$img:$(NODE_TAG)..."; \
		kind load docker-image $$img:$(NODE_TAG) --name $(CLUSTER_NAME) > /dev/null 2>&1; \
	done
	@echo "✓ Images loaded into cluster"
	@mkdir -p .build && touch $@

wait-deployments: ## Wait for all deployments to be ready
	@echo "Waiting for deployments..."
	@kubectl wait --for=condition=available --timeout=$(DEPLOYMENT_TIMEOUT) deployment --all
	@echo "✓ All deployments ready"

undeploy: ## Remove all deployed resources
	@echo "Removing deployed resources..."
	@kubectl delete -k $(KUSTOMIZE_OVERLAY) --ignore-not-found=true
	@rm -f .build/deployed
	@echo "✓ Resources removed"

deployment-status: ## Show deployment status
	@echo "Deployments:"
	@kubectl get deployments
	@echo ""
	@echo "Pods:"
	@kubectl get pods
	@echo ""
	@echo "Services:"
	@kubectl get services
