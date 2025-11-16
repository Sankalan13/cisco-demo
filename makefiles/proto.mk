# proto.mk
# Protocol buffer code generation

# Configuration
PROTO_DIR := microservices-demo/protos
PROTO_FILE := $(PROTO_DIR)/demo.proto

# Services that need proto generation
SERVICES_WITH_PROTOS := productcatalogservice checkoutservice emailservice \
                        currencyservice paymentservice shippingservice \
                        adservice frontend recommendationservice

##@ Proto Generation

.PHONY: proto-all proto-clean proto-go proto-python

proto-all: proto-go proto-python ## Generate all protobuf code

proto-go: $(SERVICES_WITH_PROTOS:%=microservices-demo/src/%/genproto/demo_pb.go) ## Generate Go protobuf code

proto-python: test-framework/generated/demo_pb2.py ## Generate Python protobuf code (handled by test.mk)

# Pattern rule for Go proto generation
microservices-demo/src/%/genproto/demo_pb.go: $(PROTO_FILE)
	@echo "Generating Go proto code for $*..."
	@mkdir -p microservices-demo/src/$*/genproto
	@cd microservices-demo/src/$* && \
		protoc --proto_path=../../protos \
		       --go_out=./genproto --go_opt=paths=source_relative \
		       --go-grpc_out=./genproto --go-grpc_opt=paths=source_relative \
		       ../../protos/demo.proto
	@echo "✓ Generated proto code for $*"

proto-clean: ## Clean all generated protobuf code
	@echo "Cleaning generated proto code..."
	@for svc in $(SERVICES_WITH_PROTOS); do \
		rm -rf microservices-demo/src/$$svc/genproto; \
	done
	@rm -rf test-framework/generated
	@echo "✓ Proto code cleaned"
