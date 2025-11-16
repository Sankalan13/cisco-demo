# test.mk
# Test execution (local and K8s modes)

# Configuration
TEST_MODE ?= local
TEST_FRAMEWORK_DIR := test-framework
DEPLOY_SCRIPTS_DIR := $(TEST_FRAMEWORK_DIR)/deploy_scripts
AUTO_APPROVE ?= 1

##@ Testing

.PHONY: test test-local test-k8s generate-protos build-test-image

test: test-$(TEST_MODE) ## Run tests (TEST_MODE=local or k8s)

test-local: .build/deployed port-forward-start generate-protos ## Run tests locally with port-forwarding
	@echo "Running tests in local mode..."
	@cd $(TEST_FRAMEWORK_DIR) && \
		behave features/ -v --junit --junit-directory reports/ 2>&1 | tee reports/behave_output.txt || true
	@echo ""
	@echo "✓ Test execution complete"
	@echo "Reports: $(TEST_FRAMEWORK_DIR)/reports/"

test-k8s: .build/test-runner-deployed ## Run tests as Kubernetes Job
	@echo "Retrieving test reports from Kubernetes..."
	@cd $(DEPLOY_SCRIPTS_DIR) && AUTO_APPROVE=$(AUTO_APPROVE) ./get_test_reports.sh
	@echo "✓ Test reports retrieved"
	@echo "Reports: $(TEST_FRAMEWORK_DIR)/reports/"

.build/test-runner-deployed: .build/deployed .build/test-framework-image
	@echo "Deploying test runner as Kubernetes Job..."
	@cd $(DEPLOY_SCRIPTS_DIR) && AUTO_APPROVE=$(AUTO_APPROVE) ./deploy_test_runner.sh
	@mkdir -p .build && touch $@
	@echo "✓ Test Job completed"

.build/test-framework-image: $(TEST_FRAMEWORK_DIR)/Dockerfile
	@echo "Building test-framework Docker image..."
	@docker build -f $(TEST_FRAMEWORK_DIR)/Dockerfile -t test-framework:latest . > /dev/null 2>&1 || \
		docker build -f $(TEST_FRAMEWORK_DIR)/Dockerfile -t test-framework:latest .
	@kind load docker-image test-framework:latest --name $(CLUSTER_NAME) > /dev/null 2>&1
	@mkdir -p .build && touch $@
	@echo "✓ Test framework image built and loaded"

build-test-image: ## Force rebuild test framework image
	@rm -f .build/test-framework-image
	@$(MAKE) .build/test-framework-image

generate-protos: $(TEST_FRAMEWORK_DIR)/generated/demo_pb2.py ## Generate Python protobuf code

$(TEST_FRAMEWORK_DIR)/generated/demo_pb2.py: microservices-demo/protos/demo.proto
	@echo "Generating Python protobuf code..."
	@cd $(TEST_FRAMEWORK_DIR) && ./generate_protos.sh
	@echo "✓ Protobuf code generated"

clean-test-reports: ## Clean test reports
	@echo "Cleaning test reports..."
	@rm -rf $(TEST_FRAMEWORK_DIR)/reports/*
	@echo "✓ Test reports cleaned"
