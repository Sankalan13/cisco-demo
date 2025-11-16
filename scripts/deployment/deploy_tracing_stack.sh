#!/bin/bash

# deploy_tracing_stack.sh
# Deploy OpenTelemetry Collector and Jaeger for test coverage tracking

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
CLUSTER_CONTEXT="kind-microservices-demo"

echo ""
print_info "========================================="
print_info "Deploying Tracing Stack for Test Coverage"
print_info "========================================="
echo ""

# Step 1: Verify cluster is accessible
print_info "Step 1: Verifying Kind cluster access..."
if ! kubectl cluster-info --context "$CLUSTER_CONTEXT" > /dev/null 2>&1; then
    print_error "Cluster '$CLUSTER_CONTEXT' is not accessible"
    print_error "Please run: ./deploy_test_cluster.sh first"
    exit 1
fi
print_success "Cluster is accessible"
echo ""

# Step 2: Deploy OpenTelemetry Collector
print_info "Step 2: Deploying OpenTelemetry Collector..."
kubectl apply -f "$SCRIPT_DIR/otel-collector-deployment.yaml" --context "$CLUSTER_CONTEXT"
print_success "OpenTelemetry Collector deployment created"
echo ""

# Step 3: Deploy Jaeger
print_info "Step 3: Deploying Jaeger..."
kubectl apply -f "$SCRIPT_DIR/jaeger-deployment.yaml" --context "$CLUSTER_CONTEXT"
print_success "Jaeger deployment created"
echo ""

# Step 4: Wait for collector to be ready
print_info "Step 4: Waiting for OpenTelemetry Collector to be ready..."
kubectl wait --for=condition=available --timeout=60s \
    deployment/opentelemetrycollector \
    --context "$CLUSTER_CONTEXT" 2>/dev/null || true

if kubectl get pods --context "$CLUSTER_CONTEXT" -l app=opentelemetrycollector | grep -q "Running"; then
    print_success "OpenTelemetry Collector is ready"
else
    print_warning "OpenTelemetry Collector may still be starting..."
    print_info "Check status with: kubectl get pods -l app=opentelemetrycollector"
fi
echo ""

# Step 5: Wait for Jaeger to be ready
print_info "Step 5: Waiting for Jaeger to be ready..."
kubectl wait --for=condition=available --timeout=60s \
    deployment/jaeger \
    --context "$CLUSTER_CONTEXT" 2>/dev/null || true

if kubectl get pods --context "$CLUSTER_CONTEXT" -l app=jaeger | grep -q "Running"; then
    print_success "Jaeger is ready"
else
    print_warning "Jaeger may still be starting..."
    print_info "Check status with: kubectl get pods -l app=jaeger"
fi
echo ""
print_success "========================================="
print_success "Observability Stack Deployment Complete!"
print_success "========================================="
echo ""

print_info "Summary:"
print_info "  ✓ OpenTelemetry Collector deployed"
print_info "  ✓ Jaeger deployed"
echo ""

print_info "Next Steps:"
print_info "  1. Enable tracing on microservices:"
print_info "     cd ../.. && ./enable_tracing.sh"
echo ""
print_info "  2. Set up port-forward to access Jaeger UI:"
print_info "     ./port_forward_services.sh --background"
echo ""
print_info "  3. Access Jaeger UI at: http://localhost:16686"
echo ""
print_info "  4. Run your tests to generate traces:"
print_info "     cd test-framework && behave"
echo ""
print_info "  5. View traces in Jaeger UI to see test coverage"
echo ""

print_info "Verification:"
print_info "  - Check OTel Collector: kubectl logs -l app=opentelemetrycollector"
print_info "  - Check Jaeger: kubectl logs -l app=jaeger"
echo ""

exit 0
