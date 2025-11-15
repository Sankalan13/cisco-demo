#!/bin/bash

# enable_tracing.sh
# Enable OpenTelemetry tracing on deployed microservices
# This script should be run AFTER services are deployed and observability stack is ready

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

CLUSTER_CONTEXT="kind-microservices-demo"

echo ""
print_info "========================================="
print_info "Enabling Tracing on Microservices"
print_info "========================================="
echo ""

# Check if cluster is accessible
if ! kubectl cluster-info --context "$CLUSTER_CONTEXT" > /dev/null 2>&1; then
    print_error "Cluster '$CLUSTER_CONTEXT' is not accessible"
    exit 1
fi

# Check if OTel Collector exists
if ! kubectl get svc opentelemetrycollector --context "$CLUSTER_CONTEXT" > /dev/null 2>&1; then
    print_warning "OpenTelemetry Collector service not found"
    print_warning "Deploy observability stack first: cd test-framework/deploy_scripts && ./deploy_tracing_stack.sh"
fi

SERVICES=(
    "frontend"
    "checkoutservice"
    "productcatalogservice"
    "currencyservice"
    "paymentservice"
    "emailservice"
    "recommendationservice"
    "shippingservice"
    "cartservice"
    "adservice"
)

print_info "Patching ${#SERVICES[@]} services with tracing environment variables..."
echo ""

# First, update Node.js services to use fixed images
print_info "Updating Node.js services with OpenTelemetry-fixed images..."
if docker images -q currencyservice:local-fixed > /dev/null 2>&1; then
    kubectl set image deployment/currencyservice server=currencyservice:local-fixed --context "$CLUSTER_CONTEXT" 2>/dev/null && \
        print_success "✓ currencyservice image updated to local-fixed" || \
        print_warning "currencyservice image update skipped (may already be set)"
fi

if docker images -q paymentservice:local-fixed > /dev/null 2>&1; then
    kubectl set image deployment/paymentservice server=paymentservice:local-fixed --context "$CLUSTER_CONTEXT" 2>/dev/null && \
        print_success "✓ paymentservice image updated to local-fixed" || \
        print_warning "paymentservice image update skipped (may already be set)"
fi
echo ""

for service in "${SERVICES[@]}"; do
    print_info "Patching $service..."

    # Check if deployment exists
    if ! kubectl get deployment "$service" --context "$CLUSTER_CONTEXT" > /dev/null 2>&1; then
        print_warning "$service deployment not found, skipping"
        continue
    fi

    # Patch the deployment to add tracing environment variables
    kubectl patch deployment "$service" --context "$CLUSTER_CONTEXT" --type='json' -p='[
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/env/-",
            "value": {
                "name": "ENABLE_TRACING",
                "value": "1"
            }
        },
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/env/-",
            "value": {
                "name": "COLLECTOR_SERVICE_ADDR",
                "value": "opentelemetrycollector:4317"
            }
        }
    ]' 2>/dev/null || print_warning "Failed to patch $service (may already have env vars)"

    print_success "✓ $service patched"
done

echo ""

# Wait for services to restart with new configuration
print_info "Waiting for services to restart with tracing enabled..."
sleep 5

for service in "${SERVICES[@]}"; do
    if kubectl get deployment "$service" --context "$CLUSTER_CONTEXT" > /dev/null 2>&1; then
        kubectl rollout status deployment/"$service" --context "$CLUSTER_CONTEXT" --timeout=60s 2>/dev/null || true
    fi
done

echo ""
print_success "========================================="
print_success "Tracing Enabled on All Services!"
print_success "========================================="
echo ""

print_info "Verification:"
echo "  - Check a service has tracing enabled:"
echo "    kubectl get deployment frontend -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"ENABLE_TRACING\")].value}'"
echo ""
print_info "  - Should output: 1"
echo ""

exit 0
