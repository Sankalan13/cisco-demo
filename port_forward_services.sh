#!/bin/bash

# port_forward_services.sh
# Automatically set up kubectl port-forwarding for all microservices-demo services
#
# Usage:
#   ./port_forward_services.sh           # Run in foreground (interactive mode)
#   ./port_forward_services.sh --background  # Run in background (automation mode)

set -e

# Check for background mode
BACKGROUND_MODE=false
if [ "$1" == "--background" ]; then
    BACKGROUND_MODE=true
fi

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

CLUSTER_NAME="microservices-demo"
NAMESPACE="default"
PID_FILE="/tmp/microservices-port-forwards.pids"

# Cleanup function
cleanup() {
    print_info "Cleaning up port-forwards..."
    if [ -f "$PID_FILE" ]; then
        while IFS= read -r pid; do
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid" 2>/dev/null || true
                print_info "Stopped port-forward (PID: $pid)"
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    print_success "Cleanup complete"
}

# Set up trap to cleanup on exit (only in foreground mode)
if [ "$BACKGROUND_MODE" = false ]; then
    trap cleanup EXIT INT TERM
fi

# Check if cluster exists and is accessible
print_info "Checking Kind cluster '${CLUSTER_NAME}'..."
if ! kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1; then
    print_error "Cannot access Kind cluster '${CLUSTER_NAME}'"
    print_error "Please run deploy_test_cluster.sh first"
    exit 1
fi

print_success "Cluster is accessible"

# Set kubectl context
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1

# Clean up any existing port-forwards
cleanup

# Service port-forward configurations
# Format: "service_name:local_port:service_port"
declare -a SERVICES=(
    "productcatalogservice:3550:3550"
    "cartservice:7070:7070"
    "recommendationservice:8080:8080"
    "checkoutservice:5050:5050"
    "currencyservice:7000:7000"
    "paymentservice:50051:50051"
    "shippingservice:50052:50051"  # Different local port to avoid conflict
    "emailservice:5000:5000"
    "adservice:9555:9555"
    "frontend:8080:80"
)

print_info "Setting up port-forwards for ${#SERVICES[@]} services..."
echo ""

# Create PID file
> "$PID_FILE"

# Set up port-forwards
for service_config in "${SERVICES[@]}"; do
    IFS=':' read -r service local_port service_port <<< "$service_config"

    print_info "Port-forwarding $service: localhost:$local_port -> $service:$service_port"

    # Start port-forward in background
    kubectl port-forward "svc/$service" "$local_port:$service_port" -n "$NAMESPACE" > /dev/null 2>&1 &

    # Save PID
    echo $! >> "$PID_FILE"

    # Give it a moment to start
    sleep 0.5

    # Verify port-forward is running
    if ps -p $! > /dev/null 2>&1; then
        print_success "✓ $service ready on localhost:$local_port"
    else
        print_warning "⚠ Failed to start port-forward for $service"
    fi
done

echo ""
print_success "========================================="
print_success "All port-forwards established!"
print_success "========================================="
echo ""

print_info "Service Endpoints:"
echo "  Product Catalog:    localhost:3550"
echo "  Cart Service:       localhost:7070"
echo "  Recommendation:     localhost:8080"
echo "  Checkout:           localhost:5050"
echo "  Currency:           localhost:7000"
echo "  Payment:            localhost:50051"
echo "  Shipping:           localhost:50052"
echo "  Email:              localhost:5000"
echo "  Ad Service:         localhost:9555"
echo "  Frontend (HTTP):    localhost:8080"
echo ""

if [ "$BACKGROUND_MODE" = true ]; then
    print_info "Port-forwards running in background"
    print_info "PIDs stored in: $PID_FILE"
    print_warning "To stop port-forwards, run: kill \$(cat $PID_FILE)"
    echo ""
else
    print_info "Port-forwards will remain active until you press Ctrl+C"
    print_warning "Do not close this terminal window while running tests!"
    echo ""
    # Keep script running and wait for Ctrl+C
    wait
fi
