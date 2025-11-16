# port-forward.mk
# Port-forwarding management (wraps shell script)

# Configuration
PORT_FORWARD_SCRIPT := scripts/port-forward.sh
PID_FILE := /tmp/microservices-port-forwards.pids

##@ Port Forwarding

.PHONY: port-forward port-forward-start port-forward-stop port-forward-status

port-forward: port-forward-start ## Start kubectl port-forwards (alias)

port-forward-start: .build/deployed ## Start kubectl port-forwards in background
	@echo "Starting port-forwards..."
	@if [ ! -f "$(PORT_FORWARD_SCRIPT)" ]; then \
		echo "Error: $(PORT_FORWARD_SCRIPT) not found"; \
		exit 1; \
	fi
	@$(PORT_FORWARD_SCRIPT) --background
	@echo "✓ Port-forwards started (PIDs in $(PID_FILE))"
	@echo ""
	@echo "Services accessible at:"
	@echo "  - Product Catalog:  localhost:3550"
	@echo "  - Cart Service:     localhost:7070"
	@echo "  - Currency:         localhost:7000"
	@echo "  - Recommendation:   localhost:8080"
	@echo "  - Checkout:         localhost:5050"
	@echo "  - Payment:          localhost:50051"
	@echo "  - Shipping:         localhost:50052"
	@echo "  - Email:            localhost:5000"
	@echo "  - Ad Service:       localhost:9555"
	@echo "  - Jaeger UI:        http://localhost:16686"

port-forward-stop: ## Stop all kubectl port-forwards
	@echo "Stopping port-forwards..."
	@if [ -f "$(PID_FILE)" ]; then \
		while IFS= read -r pid; do \
			kill $$pid 2>/dev/null || true; \
		done < "$(PID_FILE)"; \
		rm -f "$(PID_FILE)"; \
		echo "✓ Port-forwards stopped"; \
	else \
		echo "No port-forwards running (PID file not found)"; \
	fi

port-forward-status: ## Check port-forward status
	@if [ -f "$(PID_FILE)" ]; then \
		echo "Port-forward PIDs:"; \
		cat "$(PID_FILE)"; \
		echo ""; \
		echo "Running processes:"; \
		ps -p $$(cat "$(PID_FILE)" | tr '\n' ',' | sed 's/,$$//') 2>/dev/null || echo "No processes running"; \
	else \
		echo "No port-forwards running"; \
	fi
