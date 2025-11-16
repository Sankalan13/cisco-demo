# docker.mk
# Docker image building with dependency tracking and caching

# Service lists
GO_SERVICES := productcatalogservice checkoutservice shippingservice
NODE_SERVICES := currencyservice paymentservice

# Image tags
GO_TAG := local-coverage
NODE_TAG := local-fixed

# Source directories
SRC_DIR := microservices-demo/src
SHARED_DIR := $(SRC_DIR)/shared

##@ Docker Images

.PHONY: build-images build-go-images build-node-images

build-images: build-go-images build-node-images ## Build all Docker images

build-go-images: $(GO_SERVICES:%=.build/%-$(GO_TAG)) ## Build Go service images with coverage

build-node-images: $(NODE_SERVICES:%=.build/%-$(NODE_TAG)) ## Build Node.js service images with OTel fixes

# Pattern rule for Go services with coverage instrumentation
.build/%-$(GO_TAG): $(SRC_DIR)/%/**/* $(SHARED_DIR)/**/*
	@echo "Building $*:$(GO_TAG)..."
	@docker build -f $(SRC_DIR)/$*/Dockerfile \
		-t $*:$(GO_TAG) \
		$(SRC_DIR)/ > /dev/null 2>&1 || \
		docker build -f $(SRC_DIR)/$*/Dockerfile \
			-t $*:$(GO_TAG) \
			$(SRC_DIR)/
	@mkdir -p .build && touch $@
	@echo "✓ Built $*:$(GO_TAG)"

# Pattern rule for Node.js services with OTel fixes
.build/%-$(NODE_TAG): $(SRC_DIR)/%/**/*
	@echo "Building $*:$(NODE_TAG)..."
	@docker build -t $*:$(NODE_TAG) $(SRC_DIR)/$*/ > /dev/null 2>&1 || \
		docker build -t $*:$(NODE_TAG) $(SRC_DIR)/$*/
	@mkdir -p .build && touch $@
	@echo "✓ Built $*:$(NODE_TAG)"

# Clean Docker images
clean-images: ## Remove all built Docker images
	@echo "Removing Docker images..."
	@for img in $(GO_SERVICES); do \
		docker rmi -f $$img:$(GO_TAG) 2>/dev/null || true; \
	done
	@for img in $(NODE_SERVICES); do \
		docker rmi -f $$img:$(NODE_TAG) 2>/dev/null || true; \
	done
	@docker rmi -f test-framework:latest 2>/dev/null || true
	@rm -f $(GO_SERVICES:%=.build/%-$(GO_TAG)) $(NODE_SERVICES:%=.build/%-$(NODE_TAG))
	@echo "✓ Docker images removed"
