#!/bin/bash
#
# Wrapper script to run tests locally and collect Go coverage
# This script runs on the host machine, not inside the container
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info "========================================="
print_info "Running Local BDD Tests"
print_info "========================================="
echo ""

# Run tests locally using Docker
print_info "Starting test execution..."
docker run --rm \
    --network host \
    -v "$SCRIPT_DIR/reports:/app/reports" \
    -v "$SCRIPT_DIR/config:/app/config" \
    -e TEST_MODE=local \
    test-framework:latest

TEST_EXIT_CODE=$?

echo ""

if [ $TEST_EXIT_CODE -ne 0 ]; then
    print_error "Tests failed with exit code: $TEST_EXIT_CODE"
else
    print_success "✓ Tests completed successfully"
fi

echo ""

# Collect Go coverage if kubectl is available and cluster is accessible
if command -v kubectl &> /dev/null; then
    print_info "Checking if Kubernetes cluster is accessible..."

    if kubectl cluster-info &> /dev/null; then
        print_success "✓ Kubernetes cluster is accessible"
        echo ""

        # Run Go coverage collection
        if [ -f "$SCRIPT_DIR/../collect_go_coverage.sh" ]; then
            print_info "Collecting Go coverage from services..."
            "$SCRIPT_DIR/../collect_go_coverage.sh"
        else
            print_warning "⚠ Go coverage collection script not found"
            print_info "Expected location: $SCRIPT_DIR/../collect_go_coverage.sh"
        fi
    else
        print_warning "⚠ Kubernetes cluster not accessible - skipping Go coverage collection"
        print_info "To collect Go coverage, ensure kubectl is configured and cluster is running"
    fi
else
    print_warning "⚠ kubectl not found - skipping Go coverage collection"
    print_info "Install kubectl to enable Go coverage collection"
fi

echo ""
print_info "Test reports are available in: $SCRIPT_DIR/reports/"

# Exit with the test exit code
exit $TEST_EXIT_CODE
