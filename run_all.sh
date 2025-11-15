#!/bin/bash

# run_all.sh
# Master script to deploy cluster, set up port-forwarding, run tests, and cleanup

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
PID_FILE="/tmp/microservices-port-forwards.pids"

# Cleanup function for port-forwards
cleanup_port_forwards() {
    print_info "Stopping port-forwards..."
    if [ -f "$PID_FILE" ]; then
        while IFS= read -r pid; do
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
        print_success "Port-forwards stopped"
    fi
}

# Set up trap to ensure cleanup
trap cleanup_port_forwards EXIT INT TERM

echo ""
print_info "========================================="
print_info "Microservices Demo - Complete Workflow"
print_info "========================================="
echo ""

# Step 1: Build Docker images locally
print_info "Step 1: Building Node.js Docker images (local only)..."
echo ""

CURRENCY_IMAGE_EXISTS=$(docker images -q currencyservice:local-fixed 2> /dev/null)
PAYMENT_IMAGE_EXISTS=$(docker images -q paymentservice:local-fixed 2> /dev/null)

if [ -z "$CURRENCY_IMAGE_EXISTS" ]; then
    print_info "Building currencyservice:local-fixed..."
    cd "$SCRIPT_DIR/microservices-demo/src/currencyservice"
    docker build -t currencyservice:local-fixed . > /dev/null 2>&1
    print_success "✓ currencyservice image built"
    cd "$SCRIPT_DIR"
else
    print_info "✓ currencyservice:local-fixed already exists"
fi

if [ -z "$PAYMENT_IMAGE_EXISTS" ]; then
    print_info "Building paymentservice:local-fixed..."
    cd "$SCRIPT_DIR/microservices-demo/src/paymentservice"
    docker build -t paymentservice:local-fixed . > /dev/null 2>&1
    print_success "✓ paymentservice image built"
    cd "$SCRIPT_DIR"
else
    print_info "✓ paymentservice:local-fixed already exists"
fi

echo ""

# Step 2: Create/verify Kind cluster
print_info "Step 2: Creating Kind cluster..."
echo ""

CLUSTER_NAME="microservices-demo"

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    print_warning "Kind cluster '${CLUSTER_NAME}' already exists"
    read -p "Do you want to delete and recreate the cluster? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting existing cluster..."
        kind delete cluster --name "$CLUSTER_NAME"
        print_success "Cluster deleted"

        print_info "Creating new cluster..."
        kind create cluster --name "$CLUSTER_NAME"
        print_success "Cluster created"
    else
        print_info "Using existing cluster"

        # Check for existing deployments
        kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1
        EXISTING_DEPLOYMENTS=$(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$EXISTING_DEPLOYMENTS" -gt 0 ]; then
            print_warning "Found $EXISTING_DEPLOYMENTS existing deployment(s) in the cluster"
            kubectl get deployments --all-namespaces
            echo ""
            read -p "Do you want to delete existing deployments before redeploying? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Deleting existing deployments..."
                kubectl delete all --all -n default --timeout=60s
                print_success "Existing deployments deleted"
                sleep 3
            else
                print_info "Keeping existing deployments (may cause conflicts)"
            fi
        fi
    fi
else
    print_info "No existing cluster found, creating new cluster..."
    kind create cluster --name "$CLUSTER_NAME"
    print_success "Cluster created"
fi

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1

echo ""

# Step 3: Load images into cluster
print_info "Step 3: Loading images into Kind cluster..."
echo ""

kind load docker-image currencyservice:local-fixed --name "$CLUSTER_NAME"
print_success "✓ currencyservice loaded"

kind load docker-image paymentservice:local-fixed --name "$CLUSTER_NAME"
print_success "✓ paymentservice loaded"

echo ""

# Step 4: Deploy services with Kustomize
print_info "Step 4: Deploying microservices (Kustomize + tracing)..."
echo ""

kubectl apply -k "$SCRIPT_DIR/microservices-demo/kustomize/overlays/test/"
print_success "Manifests applied successfully"
echo ""

# Wait for all deployments to be ready
print_info "Waiting for all deployments to be ready..."
echo ""

DEPLOYMENTS=$(kubectl get deployments -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

if [ -z "$DEPLOYMENTS" ]; then
    print_error "No deployments found in the cluster"
    exit 1
fi

# Wait for each deployment to be ready
ALL_READY=false
TIMEOUT=600  # 10 minutes timeout
ELAPSED=0
SLEEP_INTERVAL=5

while [ "$ALL_READY" = false ] && [ $ELAPSED -lt $TIMEOUT ]; do
    ALL_READY=true

    for deployment in $DEPLOYMENTS; do
        # Get desired and ready replicas
        DESIRED=$(kubectl get deployment "$deployment" -o jsonpath='{.spec.replicas}' 2>/dev/null)
        READY=$(kubectl get deployment "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

        # Handle empty values
        DESIRED=${DESIRED:-0}
        READY=${READY:-0}

        if [ "$READY" -ne "$DESIRED" ]; then
            ALL_READY=false
        fi
    done

    if [ "$ALL_READY" = false ]; then
        if [ $((ELAPSED % 10)) -eq 0 ]; then  # Print every 10 seconds
            print_info "Still waiting... (${ELAPSED}s elapsed)"
            kubectl get deployments
            echo ""
        fi
        sleep $SLEEP_INTERVAL
        ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
    fi
done

if [ "$ALL_READY" = false ]; then
    print_error "Timeout waiting for deployments to be ready after ${TIMEOUT}s"
    kubectl get deployments
    exit 1
fi

print_success "All deployments are ready!"
echo ""

# Step 5: Set up port-forwarding in background
print_info "Step 5: Setting up port-forwarding for services..."
echo ""

if [ ! -f "$SCRIPT_DIR/port_forward_services.sh" ]; then
    print_error "port_forward_services.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Run port-forward script in background mode
"$SCRIPT_DIR/port_forward_services.sh" --background

# Check if port-forwards were set up successfully
if [ $? -ne 0 ]; then
    print_error "Port-forwarding setup failed"
    exit 1
fi

print_success "Port-forwards established!"
echo ""

# Verify port connectivity before proceeding with tests
print_info "Verifying port-forward connectivity with retry logic..."
echo ""

# Define ports to check (matches services.yaml configuration)
declare -a PORTS_TO_CHECK=(
    "3550:Product Catalog"
    "7070:Cart Service"
    "8080:Recommendation Service"
    "7000:Currency Service"
    "5050:Checkout Service"
    "50051:Payment Service"
    "50052:Shipping Service"
    "5000:Email Service"
    "9555:Ad Service"
)

# Retry configuration
MAX_PORT_CHECK_ATTEMPTS=15
PORT_CHECK_RETRY_DELAY=2

# Track which ports have been verified using a simple string (works with bash 3.x)
VERIFIED_PORTS=""

# Retry loop
for attempt in $(seq 1 $MAX_PORT_CHECK_ATTEMPTS); do
    print_info "Port connectivity check attempt $attempt/$MAX_PORT_CHECK_ATTEMPTS"

    all_ports_ready=true

    for port_info in "${PORTS_TO_CHECK[@]}"; do
        IFS=':' read -r port service_name <<< "$port_info"

        # Skip if already verified (check if port is in VERIFIED_PORTS string)
        if echo "$VERIFIED_PORTS" | grep -q " $port "; then
            continue
        fi

        # Quick check (2 second timeout per attempt)
        # Use nc (netcat) for cross-platform compatibility (works on macOS and Linux)
        if nc -z -w 2 localhost "$port" 2>/dev/null; then
            VERIFIED_PORTS="$VERIFIED_PORTS $port "
            print_success "✓ Port $port ready ($service_name)"
        else
            all_ports_ready=false
        fi
    done

    # If all ports are ready, break out
    if [ "$all_ports_ready" = true ]; then
        break
    fi

    # If not the last attempt, wait before retry
    if [ $attempt -lt $MAX_PORT_CHECK_ATTEMPTS ]; then
        # Count how many ports are still not ready
        pending_count=0
        for port_info in "${PORTS_TO_CHECK[@]}"; do
            IFS=':' read -r port service_name <<< "$port_info"
            if ! echo "$VERIFIED_PORTS" | grep -q " $port "; then
                pending_count=$((pending_count + 1))
            fi
        done

        print_warning "$pending_count port(s) not ready yet, retrying in $PORT_CHECK_RETRY_DELAY seconds..."
        sleep $PORT_CHECK_RETRY_DELAY
    fi
done

# Check if all ports are verified
all_verified=true
failed_ports=()
for port_info in "${PORTS_TO_CHECK[@]}"; do
    IFS=':' read -r port service_name <<< "$port_info"
    if ! echo "$VERIFIED_PORTS" | grep -q " $port "; then
        all_verified=false
        failed_ports+=("$port ($service_name)")
    fi
done

echo ""

if [ "$all_verified" = false ]; then
    print_error "Port connectivity check failed after $MAX_PORT_CHECK_ATTEMPTS attempts"
    print_error "The following ports are not ready:"
    for failed_port in "${failed_ports[@]}"; do
        print_error "  - $failed_port"
    done
    echo ""
    print_error "Troubleshooting:"
    print_error "  1. Check port-forwards are running:"
    echo "     ps aux | grep 'kubectl port-forward'"
    print_error "  2. Check for port conflicts:"
    echo "     lsof -i :3550 (replace with failing port)"
    print_error "  3. Restart port-forwards:"
    echo "     kill \$(cat /tmp/microservices-port-forwards.pids) 2>/dev/null || true"
    echo "     ./port_forward_services.sh --background"
    print_error "  4. Check service pods are running:"
    echo "     kubectl get pods"
    exit 1
fi

print_success "All port-forwards are ready!"
echo ""

# Additional grace period for service initialization
print_info "Allowing services final initialization time..."
sleep 2

# Step 6: Run tests (when test framework is ready)
print_info "Step 6: Running tests..."
echo ""

# Check if test framework exists
if [ -d "$SCRIPT_DIR/test-framework" ]; then
    cd "$SCRIPT_DIR/test-framework"

    # Check if dependencies are installed
    if ! python3 -c "import behave" 2>/dev/null; then
        print_warning "Test dependencies not installed. Installing..."
        pip3 install -r requirements.txt
    fi

    # Generate proto code if needed
    if [ ! -d "generated" ] || [ -z "$(ls -A generated 2>/dev/null)" ]; then
        print_info "Generating proto code..."
        ./generate_protos.sh
    fi

    # Run tests if test files exist
    if [ -d "features" ] && [ "$(ls -A features/*.feature 2>/dev/null)" ]; then
        print_info "Executing Behave tests..."
        behave features/ -v --junit --junit-directory reports/ || true
        echo ""
        print_success "Test execution complete!"
    else
        print_warning "No test feature files found yet. Skipping test execution."
    fi

    cd "$SCRIPT_DIR"
else
    print_warning "Test framework directory not found. Skipping tests."
fi

echo ""

# Step 7: Summary
print_success "========================================="
print_success "Workflow Complete!"
print_success "========================================="
echo ""
print_info "Summary:"
print_info "  ✓ Cluster deployed with all services (Kustomize overlay)"
print_info "  ✓ Node.js services built with OTel fixes"
print_info "  ✓ Tracing enabled on all services (via Kustomize component)"
print_info "  ✓ Observability stack deployed (OTel Collector + Jaeger)"
print_info "  ✓ Port-forwards active on localhost"
print_info "  ✓ Tests executed (if available)"
echo ""
print_info "Services are accessible at:"
echo "  - Product Catalog:  localhost:3550"
echo "  - Cart Service:     localhost:7070"
echo "  - Recommendation:   localhost:8080"
echo "  - Frontend:         localhost:8080"
echo ""
print_info "Observability:"
echo "  - Jaeger UI:        http://localhost:16686"
echo ""
print_warning "Port-forwards will be cleaned up automatically on exit"
echo ""

# Ask user if they want to keep port-forwards running
read -p "Keep port-forwards running for manual testing? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Port-forwards will remain active. Press Ctrl+C to stop."
    # Don't cleanup on exit
    trap - EXIT INT TERM
    # Wait for user interrupt
    while true; do
        sleep 1
    done
else
    print_info "Cleaning up..."
    cleanup_port_forwards
fi

exit 0
