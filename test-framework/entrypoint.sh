#!/bin/bash
#
# Test Framework Container Entrypoint
# Runs BDD tests, flushes OpenTelemetry spans, and generates coverage reports

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Framework Starting${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "Test Mode: ${TEST_MODE:-local}"
echo -e "Working Directory: $(pwd)"
echo -e "Reports Directory: /app/reports"
echo ""

# Verify configuration file exists
if [ "$TEST_MODE" = "kubernetes" ]; then
    CONFIG_FILE="/app/config/services-k8s.yaml"
else
    CONFIG_FILE="/app/config/services.yaml"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}WARNING: Configuration file not found: $CONFIG_FILE${NC}"
    echo "Available config files:"
    ls -la /app/config/
fi

# Run Behave tests
echo -e "${BLUE}Running BDD tests with Behave...${NC}"
echo ""

behave /app/features/ \
    -v \
    --junit \
    --junit-directory /app/reports/ \
    --no-capture \
    || TEST_EXIT_CODE=$?

echo ""

# Check test exit code
if [ "${TEST_EXIT_CODE:-0}" -ne 0 ]; then
    echo -e "${YELLOW}Tests completed with failures (exit code: ${TEST_EXIT_CODE})${NC}"
else
    echo -e "${GREEN}✓ All tests passed${NC}"
fi

echo ""

# Note: Span flushing is handled automatically by environment.py after_all hook
# The after_all hook calls force_flush() with 10-second timeout and waits 2 seconds

# Additional wait for traces to propagate to Jaeger
echo -e "${BLUE}Waiting for distributed traces to propagate to Jaeger...${NC}"
sleep 5
echo -e "${GREEN}✓ Trace propagation complete${NC}"
echo ""

# ============================================
# Go Coverage Collection
# ============================================

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Collecting Go Code Coverage${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# List of Go services with coverage instrumentation
GO_SERVICES="productcatalogservice checkoutservice shippingservice"

# Step 1: Trigger coverage dump via SIGUSR1 signal
echo -e "${BLUE}Step 1: Triggering coverage dumps from running Go services...${NC}"
for service in $GO_SERVICES; do
    # Find pod name for service
    POD=$(kubectl get pods -l app=$service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$POD" ]; then
        echo "  Sending SIGUSR1 to $service (pod: $POD)"
        # Use busybox in distroless:debug image
        kubectl exec "$POD" -- /busybox/sh -c '/busybox/kill -USR1 1' 2>/dev/null || {
            echo -e "${YELLOW}    Warning: Could not signal $service${NC}"
        }
    else
        echo -e "${YELLOW}    Warning: Pod not found for $service${NC}"
    fi
done

# Wait for coverage files to be written
echo "  Waiting for coverage files to be written..."
sleep 3
echo -e "${GREEN}✓ Coverage dump signals sent${NC}"
echo ""

# Step 2: Collect coverage files from each service
echo -e "${BLUE}Step 2: Downloading coverage files from pods...${NC}"
mkdir -p /app/reports/go-coverage

for service in $GO_SERVICES; do
    POD=$(kubectl get pods -l app=$service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$POD" ]; then
        echo "  Collecting from $service..."
        mkdir -p "/app/reports/go-coverage/$service"

        # Copy coverage directory from pod to local
        kubectl cp "$POD:/coverage-data" "/app/reports/go-coverage/$service/" 2>/dev/null || {
            echo -e "${YELLOW}    Warning: No coverage data from $service${NC}"
        }
    fi
done

echo -e "${GREEN}✓ Coverage files downloaded${NC}"
echo ""

# Step 3: Process and merge coverage
echo -e "${BLUE}Step 3: Processing Go coverage data...${NC}"

# Build input paths for merge (only include directories that have coverage files)
COVERAGE_INPUTS=""
for service in $GO_SERVICES; do
    # Check both possible locations for coverage files
    SERVICE_DIR="/app/reports/go-coverage/$service"
    COVERAGE_DATA_DIR="$SERVICE_DIR/coverage-data"

    # Move files from subdirectory if they exist there
    if [ -d "$COVERAGE_DATA_DIR" ] && ls "$COVERAGE_DATA_DIR/"cov* >/dev/null 2>&1; then
        mv "$COVERAGE_DATA_DIR/"* "$SERVICE_DIR/" 2>/dev/null || true
        rmdir "$COVERAGE_DATA_DIR" 2>/dev/null || true
    fi

    # Add to merge inputs if coverage files exist
    if [ -d "$SERVICE_DIR" ] && ls "$SERVICE_DIR/"cov* >/dev/null 2>&1; then
        if [ -z "$COVERAGE_INPUTS" ]; then
            COVERAGE_INPUTS="$SERVICE_DIR"
        else
            COVERAGE_INPUTS="$COVERAGE_INPUTS,$SERVICE_DIR"
        fi
    fi
done

if [ -n "$COVERAGE_INPUTS" ]; then
    echo "  Merging coverage data from all services..."

    # Merge coverage from all services
    if go tool covdata merge -i="$COVERAGE_INPUTS" -o=/app/reports/go-coverage/merged 2>/dev/null; then
        echo "  Generating coverage reports..."

        # Generate merged text format
        go tool covdata textfmt \
            -i=/app/reports/go-coverage/merged \
            -o=/app/reports/go-coverage.txt 2>/dev/null

        # Get summary statistics
        go tool covdata percent \
            -i=/app/reports/go-coverage/merged \
            > /app/reports/go-coverage-summary.txt 2>/dev/null

        # Generate per-service HTML reports (source code is in /app/microservices-demo/src/)
        echo "  Generating per-service HTML reports..."
        for service in $GO_SERVICES; do
            SERVICE_SRC_DIR="/app/microservices-demo/src/$service"
            SERVICE_COV_DIR="/app/reports/go-coverage/$service"

            if [ -d "$SERVICE_SRC_DIR" ] && [ -d "$SERVICE_COV_DIR" ] && ls "$SERVICE_COV_DIR/"cov* >/dev/null 2>&1; then
                cd "$SERVICE_SRC_DIR"

                # Generate text format for this service only
                go tool covdata textfmt \
                    -i="$SERVICE_COV_DIR" \
                    -o="/app/reports/go-coverage-$service.txt" 2>/dev/null || continue

                # Generate HTML from the service-specific coverage
                if go tool cover \
                    -html="/app/reports/go-coverage-$service.txt" \
                    -o="/app/reports/go-coverage-$service.html" 2>/dev/null; then
                    echo "    ✓ Generated HTML for $service"
                fi
            fi
        done

        echo -e "${GREEN}✓ Go coverage reports generated${NC}"
    else
        echo -e "${YELLOW}Warning: Coverage merge failed (this is normal if no coverage was collected)${NC}"
    fi
else
    echo -e "${YELLOW}No Go coverage data found${NC}"
fi

echo ""

# Generate coverage report from Jaeger traces
echo -e "${BLUE}Generating test coverage metrics from Jaeger...${NC}"
echo ""

python3 /app/generate_coverage.py \
    --output /app/reports/coverage.json \
    || COVERAGE_EXIT_CODE=$?

echo ""

# Check coverage generation exit code
if [ "${COVERAGE_EXIT_CODE:-0}" -ne 0 ]; then
    echo -e "${YELLOW}Coverage generation completed with warnings (exit code: ${COVERAGE_EXIT_CODE})${NC}"
else
    echo -e "${GREEN}✓ Coverage report generated successfully${NC}"
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Execution Summary${NC}"
echo -e "${BLUE}=========================================${NC}"

# Display trace-based coverage summary if report exists
if [ -f "/app/reports/coverage.json" ]; then
    echo -e "${GREEN}Trace-Based Coverage Metrics (Integration-Level):${NC}"
    python3 -c "
import json
import sys
try:
    with open('/app/reports/coverage.json') as f:
        report = json.load(f)
    summary = report.get('summary', {})
    print(f\"  Total Services: {summary.get('total_services', 0)}\")
    print(f\"  Covered Services: {summary.get('covered_services', 0)}\")
    print(f\"  Service Coverage: {summary.get('service_coverage_percentage', 0.0)}%\")
    print(f\"  Total Methods: {summary.get('total_methods', 0)}\")
    print(f\"  Covered Methods: {summary.get('covered_methods', 0)}\")
    print(f\"  Method Coverage: {summary.get('method_coverage_percentage', 0.0)}%\")
except Exception as e:
    print(f\"  Error reading coverage report: {e}\")
    sys.exit(0)  # Don't fail on summary display errors
"
    echo ""
fi

# Display Go code coverage summary if report exists
if [ -f "/app/reports/go-coverage-summary.txt" ]; then
    echo -e "${GREEN}Go Code Coverage Metrics (Code-Level):${NC}"
    cat /app/reports/go-coverage-summary.txt | sed 's/^/  /'
    echo ""
fi

# List generated reports
echo -e "${BLUE}Generated Reports:${NC}"
ls -lh /app/reports/ 2>/dev/null || echo "  No reports found"
echo ""

# Keep container alive for a brief period to allow log collection
echo -e "${BLUE}Keeping container alive for log collection...${NC}"
sleep 10

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Test framework execution complete${NC}"
echo -e "${GREEN}=========================================${NC}"

# Exit with test exit code (0 if tests passed, non-zero if failed)
exit ${TEST_EXIT_CODE:-0}
