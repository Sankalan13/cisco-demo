# coverage.mk
# Coverage collection and generation

# Configuration
COVERAGE_SCRIPT := scripts/collect-coverage.sh
REPORTS_DIR := test-framework/reports

##@ Coverage

.PHONY: coverage collect-go-coverage generate-trace-coverage coverage-summary

coverage: generate-trace-coverage collect-go-coverage coverage-summary ## Generate all coverage reports

generate-trace-coverage: $(REPORTS_DIR)/test_execution_time.json ## Generate coverage from Jaeger traces
	@echo "Generating trace-based coverage from Jaeger..."
	@cd test-framework && \
		python3 generate_coverage.py \
			--start-time $$(jq -r .start_time reports/test_execution_time.json) \
			--end-time $$(jq -r .end_time reports/test_execution_time.json) \
			--output reports/coverage.json 2>/dev/null || \
		echo "⚠ Coverage generation failed (Jaeger may not be available)"
	@if [ -f "$(REPORTS_DIR)/coverage.json" ]; then \
		echo "✓ Trace coverage generated: $(REPORTS_DIR)/coverage.json"; \
	fi

collect-go-coverage: .build/go-coverage-collected ## Collect Go code coverage from services

.build/go-coverage-collected: test-local
	@echo "Collecting Go coverage from services..."
	@if [ -f "$(COVERAGE_SCRIPT)" ]; then \
		$(COVERAGE_SCRIPT) && echo "✓ Go coverage collected"; \
	else \
		echo "⚠ Coverage script not found: $(COVERAGE_SCRIPT)"; \
	fi
	@mkdir -p .build && touch $@

coverage-summary: ## Display test and coverage summary
	@echo ""
	@echo "========================================"
	@echo "Behave Test Summary:"
	@echo "========================================"
	@if [ -f "$(REPORTS_DIR)/behave_output.txt" ]; then \
		tail -5 "$(REPORTS_DIR)/behave_output.txt" | grep -E "(features|scenarios|steps|Took)" || \
		echo "Behave summary not available in output"; \
	else \
		echo "Behave output not found"; \
	fi
	@echo ""
	@echo "========================================"
	@echo "API Coverage Metrics"
	@echo "========================================"
	@if [ -f "$(REPORTS_DIR)/coverage.json" ]; then \
		python3 -c "import json; \
			report = json.load(open('$(REPORTS_DIR)/coverage.json')); \
			summary = report.get('summary', {}); \
			print(f\"  Total Services: {summary.get('total_services', 0)}\"); \
			print(f\"  Covered Services: {summary.get('covered_services', 0)}\"); \
			print(f\"  Service Coverage: {summary.get('service_coverage_percentage', 0)}%\"); \
			print(f\"  Total Methods: {summary.get('total_methods', 0)}\"); \
			print(f\"  Covered Methods: {summary.get('covered_methods', 0)}\"); \
			print(f\"  Method Coverage: {summary.get('method_coverage_percentage', 0)}%\")"; \
	else \
		echo "  Coverage metrics not available"; \
	fi
	@echo "========================================"
	@echo "Golang Coverage Summary:"
	@echo "========================================"
	@if [ -f "$(REPORTS_DIR)/go-coverage-summary.txt" ]; then \
		cat "$(REPORTS_DIR)/go-coverage-summary.txt"; \
	else \
		echo "Go coverage not available"; \
	fi
	@echo ""
	@echo ""
	@echo "========================================"
	@echo "Reports"
	@echo "========================================"
	@echo "  Location: $(REPORTS_DIR)/"
	@echo "  - Behave output: behave_output.txt"
	@echo "  - JUnit XML: TESTS-*.xml"
	@echo "  - Trace coverage: coverage.json"
	@echo "  - Go coverage: go-coverage-*.html"
	@echo "========================================"

clean-coverage: ## Clean coverage reports
	@echo "Cleaning coverage reports..."
	@rm -f $(REPORTS_DIR)/coverage.json
	@rm -f $(REPORTS_DIR)/behave_output.txt
	@rm -f $(REPORTS_DIR)/go-coverage-*.{txt,html}
	@rm -f .build/go-coverage-collected
	@echo "✓ Coverage reports cleaned"
