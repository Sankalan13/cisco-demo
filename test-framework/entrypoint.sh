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

# Display coverage summary if report exists
if [ -f "/app/reports/coverage.json" ]; then
    echo -e "${GREEN}Coverage Metrics:${NC}"
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
