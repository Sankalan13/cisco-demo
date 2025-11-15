#!/bin/bash

# build_fixed_node_services.sh
# Builds and loads Docker images for Node.js services with OpenTelemetry fixes
# This script ensures currencyservice and paymentservice have compatible OTel dependencies

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="microservices-demo"

echo ""
print_info "========================================="
print_info "Building Fixed Node.js Service Images"
print_info "========================================="
echo ""

# Check if images already exist locally
CURRENCY_IMAGE_EXISTS=$(docker images -q currencyservice:local-fixed 2> /dev/null)
PAYMENT_IMAGE_EXISTS=$(docker images -q paymentservice:local-fixed 2> /dev/null)

print_info "Building Docker images with OpenTelemetry fixes..."
echo ""

# Build currencyservice (or use cached version)
if [ -z "$CURRENCY_IMAGE_EXISTS" ]; then
    print_info "Building currencyservice:local-fixed..."
    cd "$SCRIPT_DIR/microservices-demo/src/currencyservice"
    docker build -t currencyservice:local-fixed . > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "✓ currencyservice image built"
    else
        print_error "Failed to build currencyservice"
        exit 1
    fi
    cd "$SCRIPT_DIR"
else
    print_info "✓ currencyservice:local-fixed already exists (using cached image)"
fi

# Build paymentservice (or use cached version)
if [ -z "$PAYMENT_IMAGE_EXISTS" ]; then
    print_info "Building paymentservice:local-fixed..."
    cd "$SCRIPT_DIR/microservices-demo/src/paymentservice"
    docker build -t paymentservice:local-fixed . > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "✓ paymentservice image built"
    else
        print_error "Failed to build paymentservice"
        exit 1
    fi
    cd "$SCRIPT_DIR"
else
    print_info "✓ paymentservice:local-fixed already exists (using cached image)"
fi
echo ""

# Check if Kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    print_warning "Kind cluster '${CLUSTER_NAME}' not found"
    print_warning "Images will be available locally but not loaded to cluster"
    echo ""
    exit 0
fi

print_info "Loading images into Kind cluster '${CLUSTER_NAME}'..."
print_info "Note: This ensures images are available even after cluster recreation"
echo ""

# Load currencyservice image - always attempt to load
print_info "Loading currencyservice:local-fixed..."
if kind load docker-image currencyservice:local-fixed --name "$CLUSTER_NAME" 2>&1 | grep -q "Image.*not yet present"; then
    print_success "✓ currencyservice image loaded to cluster"
elif kind load docker-image currencyservice:local-fixed --name "$CLUSTER_NAME" 2>&1; then
    print_success "✓ currencyservice image available in cluster"
else
    print_error "Failed to load currencyservice image to cluster"
    exit 1
fi

# Load paymentservice image - always attempt to load
print_info "Loading paymentservice:local-fixed..."
if kind load docker-image paymentservice:local-fixed --name "$CLUSTER_NAME" 2>&1 | grep -q "Image.*not yet present"; then
    print_success "✓ paymentservice image loaded to cluster"
elif kind load docker-image paymentservice:local-fixed --name "$CLUSTER_NAME" 2>&1; then
    print_success "✓ paymentservice image available in cluster"
else
    print_error "Failed to load paymentservice image to cluster"
    exit 1
fi

echo ""
print_success "========================================="
print_success "Node.js Images Ready!"
print_success "========================================="
echo ""

print_info "Summary:"
print_info "  ✓ currencyservice:local-fixed - Built and loaded"
print_info "  ✓ paymentservice:local-fixed - Built and loaded"
echo ""

print_info "Note: These images have updated OpenTelemetry dependencies"
print_info "  - Added @opentelemetry/sdk-trace-node@1.30.1"
print_info "  - Updated @opentelemetry/exporter-trace-otlp-grpc@0.52.1"
echo ""

exit 0
