#!/bin/bash
#
# Build Go services with coverage instrumentation and load into Kind cluster
# Follows same pattern as build_fixed_node_services.sh
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

CLUSTER_NAME="microservices-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go services to build with coverage instrumentation
GO_SERVICES=("productcatalogservice" "checkoutservice" "shippingservice")

print_info "========================================="
print_info "Building Go Services with Coverage"
print_info "========================================="
echo ""

for service in "${GO_SERVICES[@]}"; do
    IMAGE_NAME="${service}:local-coverage"

    # Check if image already exists (caching)
    IMAGE_EXISTS=$(docker images -q "$IMAGE_NAME" 2> /dev/null)

    if [ -n "$IMAGE_EXISTS" ]; then
        print_warning "Image $IMAGE_NAME already exists (using cached version)"
        print_info "To rebuild, run: docker rmi $IMAGE_NAME"
    else
        print_info "Building $IMAGE_NAME..."
        # Build from src directory with service as context to have access to shared module
        cd "$SCRIPT_DIR/microservices-demo/src"

        if docker build -f "$service/Dockerfile" -t "$IMAGE_NAME" . ; then
            print_success "✓ Built $IMAGE_NAME"
        else
            print_error "✗ Failed to build $IMAGE_NAME"
            exit 1
        fi
    fi

    # Load into Kind cluster if it exists
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_info "Loading $IMAGE_NAME into Kind cluster..."

        if kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME" ; then
            print_success "✓ Loaded $IMAGE_NAME into cluster"
        else
            print_warning "Warning: Could not load $IMAGE_NAME into cluster"
        fi
    else
        print_warning "Kind cluster '$CLUSTER_NAME' not found"
        print_info "Cluster will be created later in the deployment process"
        print_info "Images will be loaded after cluster creation"
    fi

    echo ""
done

print_success "========================================="
print_success "Go services build complete"
print_success "========================================="
echo ""

print_info "Summary:"
for service in "${GO_SERVICES[@]}"; do
    IMAGE_NAME="${service}:local-coverage"
    if docker images -q "$IMAGE_NAME" 2> /dev/null | grep -q .; then
        print_success "  ✓ ${service}:local-coverage"
    else
        print_error "  ✗ ${service}:local-coverage (MISSING)"
    fi
done

echo ""
print_info "Note: These images are built with Go coverage instrumentation"
print_info "Coverage can be collected using SIGUSR1 signal without stopping the services"
