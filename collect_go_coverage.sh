#!/bin/bash
#
# Collect Go coverage from running services in Kubernetes cluster
# Can be run independently after tests complete
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="$SCRIPT_DIR/test-framework/reports"
GO_SERVICES="productcatalogservice checkoutservice shippingservice"

print_info "========================================="
print_info "Collecting Go Coverage from Services"
print_info "========================================="
echo ""

# Create coverage directory
mkdir -p "$REPORTS_DIR/go-coverage"
rm -rf "$REPORTS_DIR/go-coverage"/*

print_info "Step 1: Triggering coverage dump via SIGUSR1..."
echo ""

for service in $GO_SERVICES; do
    print_info "  Triggering coverage dump for $service..."

    # Get the pod name for the service
    POD=$(kubectl get pods -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -z "$POD" ]; then
        print_warning "  ⚠ Pod for $service not found, skipping..."
        continue
    fi

    # Send SIGUSR1 signal to trigger coverage dump
    # Use busybox in distroless:debug image
    if kubectl exec "$POD" -- /busybox/sh -c '/busybox/kill -USR1 1' 2>/dev/null; then
        print_success "  ✓ Triggered coverage dump for $service (pod: $POD)"
    else
        print_warning "  ⚠ Failed to trigger coverage dump for $service"
    fi
done

echo ""
print_info "Step 2: Waiting for coverage files to be written..."
sleep 3
echo ""

print_info "Step 3: Collecting coverage files from pods..."
echo ""

COVERAGE_INPUTS=""
for service in $GO_SERVICES; do
    print_info "  Collecting coverage from $service..."

    POD=$(kubectl get pods -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -z "$POD" ]; then
        print_warning "  ⚠ Pod for $service not found, skipping..."
        continue
    fi

    # Create service-specific directory
    mkdir -p "$REPORTS_DIR/go-coverage/$service"

    # Copy coverage files from pod
    # kubectl cp creates a subdirectory named after the source directory
    if kubectl cp "$POD:/coverage-data" "$REPORTS_DIR/go-coverage/$service/" 2>/dev/null; then
        # Check if any coverage files were collected (covmeta.* or covcounters.*)
        # Files are in the current service directory (kubectl cp extracts them)
        if ls "$REPORTS_DIR/go-coverage/$service/"cov* >/dev/null 2>&1; then
            print_success "  ✓ Collected coverage files from $service"
            COVERAGE_INPUTS="$COVERAGE_INPUTS,$REPORTS_DIR/go-coverage/$service"
        else
            print_warning "  ⚠ No coverage files found for $service"
        fi
    else
        print_warning "  ⚠ Failed to copy coverage files from $service"
    fi
done

# Remove leading comma from COVERAGE_INPUTS
COVERAGE_INPUTS="${COVERAGE_INPUTS#,}"

echo ""

if [ -z "$COVERAGE_INPUTS" ]; then
    print_error "========================================="
    print_error "No coverage data collected"
    print_error "========================================="
    echo ""
    print_info "Possible reasons:"
    print_info "  1. Services were not built with coverage instrumentation"
    print_info "  2. Services have not received any requests yet"
    print_info "  3. GOCOVERDIR is not set in service containers"
    echo ""
    print_info "Make sure to run tests before collecting coverage"
    exit 1
fi

print_info "Step 4: Processing and merging coverage data..."
echo ""

# Check if go is available
if ! command -v go &> /dev/null; then
    print_error "Go toolchain not found. Please install Go to process coverage data."
    print_info "Coverage data has been collected to: $REPORTS_DIR/go-coverage/"
    print_info "You can process it manually using: go tool covdata"
    exit 1
fi

# Merge coverage data
print_info "  Merging coverage data..."
mkdir -p "$REPORTS_DIR/go-coverage/merged"

if go tool covdata merge -i="$COVERAGE_INPUTS" -o="$REPORTS_DIR/go-coverage/merged" 2>/dev/null; then
    print_success "  ✓ Merged coverage data"
else
    print_error "  ✗ Failed to merge coverage data"
    exit 1
fi

# Convert to text format
print_info "  Converting to text format..."
if go tool covdata textfmt -i="$REPORTS_DIR/go-coverage/merged" -o="$REPORTS_DIR/go-coverage.txt" 2>/dev/null; then
    print_success "  ✓ Generated text coverage report"
else
    print_error "  ✗ Failed to generate text coverage report"
    exit 1
fi

# Generate per-service HTML reports
print_info "  Generating HTML reports for each service..."
for service in $GO_SERVICES; do
    SERVICE_DIR="$SCRIPT_DIR/microservices-demo/src/$service"
    if [ -d "$SERVICE_DIR" ] && [ -d "$REPORTS_DIR/go-coverage/$service" ]; then
        cd "$SERVICE_DIR"
        # Generate text format for this service only
        go tool covdata textfmt -i="$REPORTS_DIR/go-coverage/$service" -o="$REPORTS_DIR/go-coverage-$service.txt" 2>/dev/null || continue
        # Generate HTML from the service-specific coverage
        if go tool cover -html="$REPORTS_DIR/go-coverage-$service.txt" -o="$REPORTS_DIR/go-coverage-$service.html" 2>/dev/null; then
            print_success "    ✓ Generated HTML for $service"
        fi
    fi
done
cd "$SCRIPT_DIR"

# Generate coverage summary
print_info "  Generating coverage summary..."
go tool covdata percent -i="$REPORTS_DIR/go-coverage/merged" > "$REPORTS_DIR/go-coverage-summary.txt" 2>/dev/null || true

echo ""
print_success "========================================="
print_success "Go Coverage Collection Complete"
print_success "========================================="
echo ""

if [ -f "$REPORTS_DIR/go-coverage-summary.txt" ]; then
    print_success "Coverage Summary:"
    cat "$REPORTS_DIR/go-coverage-summary.txt"
    echo ""
fi

print_info "Reports generated:"
print_success "  ✓ Merged text:    $REPORTS_DIR/go-coverage.txt"
print_success "  ✓ Summary:        $REPORTS_DIR/go-coverage-summary.txt"
echo ""
print_info "Per-service HTML reports:"
for service in $GO_SERVICES; do
    if [ -f "$REPORTS_DIR/go-coverage-$service.html" ]; then
        print_success "  ✓ $service:       $REPORTS_DIR/go-coverage-$service.html"
    fi
done
echo ""

print_info "To view coverage reports:"
for service in $GO_SERVICES; do
    if [ -f "$REPORTS_DIR/go-coverage-$service.html" ]; then
        print_info "  open $REPORTS_DIR/go-coverage-$service.html"
    fi
done
echo ""
