#!/bin/bash
#
# deploy_test_runner.sh
# Builds Docker image, loads into Kind cluster, and deploys test runner Job
#
# Usage:
#   ./deploy_test_runner.sh           # Interactive mode (prompts for PVC deletion)
#   AUTO_APPROVE=1 ./deploy_test_runner.sh  # Non-interactive mode (keeps existing PVC)
#
# Environment Variables:
#   AUTO_APPROVE - Skip interactive prompts (useful for CI/CD)
#   CI - Automatically detected in CI environments

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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_FRAMEWORK_DIR="$PROJECT_ROOT/test-framework"
CLUSTER_NAME="microservices-demo"

echo ""
print_info "========================================="
print_info "Test Runner Deployment"
print_info "========================================="
echo ""

# Step 1: Verify Kind cluster exists
print_info "Step 1: Verifying Kind cluster '${CLUSTER_NAME}' exists..."

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    print_error "Kind cluster '${CLUSTER_NAME}' not found"
    print_error "Please run ./run_all.sh first to create the cluster"
    exit 1
fi

print_success "Cluster found"
echo ""

# Set kubectl context
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1

# Step 2: Build Docker image
print_info "Step 2: Building test-framework Docker image..."

# Build from project root to access microservices-demo/protos/
cd "$PROJECT_ROOT"
docker build -f test-framework/Dockerfile -t test-framework:latest .

if [ $? -ne 0 ]; then
    print_error "Docker build failed"
    exit 1
fi

print_success "Docker image built successfully"
echo ""

# Step 3: Load image into Kind cluster
print_info "Step 3: Loading image into Kind cluster..."

kind load docker-image test-framework:latest --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    print_error "Failed to load image into Kind cluster"
    exit 1
fi

print_success "Image loaded into cluster"
echo ""

# Step 4: Apply RBAC configuration
print_info "Step 4: Applying RBAC configuration..."

kubectl apply -f "$SCRIPT_DIR/test-runner-rbac.yaml"

print_success "RBAC configured"
echo ""

# Step 5: Delete existing Job first (BEFORE PVC deletion)
print_info "Step 5: Cleaning up any existing test-runner Job..."

if kubectl get job test-runner >/dev/null 2>&1; then
    print_info "Deleting existing Job..."
    kubectl delete job test-runner --timeout=60s || true

    # Wait for pod to be fully terminated (important for PVC release)
    print_info "Waiting for pod to terminate..."
    sleep 5

    # Verify no pods are using the PVC
    POD_COUNT=$(kubectl get pods -l job-name=test-runner --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$POD_COUNT" -gt 0 ]; then
        print_warning "Waiting for pod cleanup..."
        kubectl wait --for=delete pod -l job-name=test-runner --timeout=30s 2>/dev/null || true
    fi

    print_success "Existing Job deleted"
else
    print_info "No existing Job found"
fi

echo ""

# Step 6: Create/verify PVC
print_info "Step 6: Creating PersistentVolumeClaim for test reports..."

# Check if PVC already exists
if kubectl get pvc test-reports >/dev/null 2>&1; then
    print_warning "PVC 'test-reports' already exists"

    # In CI/CD mode, automatically keep existing PVC (don't prompt)
    if [ -n "$CI" ] || [ -n "$AUTO_APPROVE" ]; then
        print_info "CI mode detected - keeping existing PVC"
    else
        # Ask user if they want to delete and recreate
        read -p "Delete existing PVC and recreate? This will delete previous test reports. (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing PVC..."
            kubectl delete pvc test-reports --timeout=60s

            # Wait for PVC to be fully deleted
            print_info "Waiting for PVC deletion to complete..."
            kubectl wait --for=delete pvc/test-reports --timeout=30s 2>/dev/null || true

            print_success "PVC deleted"
        else
            print_info "Keeping existing PVC"
        fi
    fi
fi

# Apply PVC if it doesn't exist
if ! kubectl get pvc test-reports >/dev/null 2>&1; then
    kubectl apply -f "$SCRIPT_DIR/test-reports-pvc.yaml"
    print_success "PVC created"
    print_info "Note: PVC will be bound when the Job pod starts"
else
    print_info "Using existing PVC"
fi

echo ""

# Step 7: Deploy test runner Job
print_info "Step 7: Deploying test-runner Job..."

kubectl apply -f "$SCRIPT_DIR/test-runner-job.yaml"

print_success "Job deployed"
echo ""

# Step 8: Wait for Job to start
print_info "Step 8: Waiting for Job to start..."

TIMEOUT=60
ELAPSED=0
SLEEP_INTERVAL=2

while [ $ELAPSED -lt $TIMEOUT ]; do
    POD_STATUS=$(kubectl get pods -l job-name=test-runner -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")

    if [ "$POD_STATUS" = "Running" ] || [ "$POD_STATUS" = "Succeeded" ] || [ "$POD_STATUS" = "Failed" ]; then
        break
    fi

    sleep $SLEEP_INTERVAL
    ELAPSED=$((ELAPSED + SLEEP_INTERVAL))

    if [ $((ELAPSED % 10)) -eq 0 ]; then
        print_info "Still waiting... (${ELAPSED}s elapsed)"
    fi
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "Timeout waiting for Job to start"
    print_info "Current Job status:"
    kubectl get job test-runner
    kubectl get pods -l job-name=test-runner
    exit 1
fi

print_success "Job started"
echo ""

# Step 9: Stream Job logs
print_info "Step 9: Streaming Job logs..."
print_info "========================================="
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -l job-name=test-runner -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    print_error "Could not find Job pod"
    exit 1
fi

# Follow logs
kubectl logs -f "$POD_NAME" || true

echo ""
print_info "========================================="
echo ""

# Step 10: Check Job status
print_info "Step 10: Checking Job completion status..."

JOB_STATUS=$(kubectl get job test-runner -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")

if [ "$JOB_STATUS" = "Complete" ]; then
    print_success "Job completed successfully"
    EXIT_CODE=0
elif [ "$JOB_STATUS" = "Failed" ]; then
    print_error "Job failed"
    EXIT_CODE=1
else
    print_warning "Job status: $JOB_STATUS"
    EXIT_CODE=0
fi

echo ""

# Step 11: Instructions for retrieving reports
print_info "========================================="
print_info "Test execution complete!"
print_info "========================================="
echo ""
print_info "To retrieve test reports to your local machine, run:"
echo "  cd $SCRIPT_DIR"
echo "  ./get_test_reports.sh"
echo ""
print_info "Reports are stored in the PVC and will persist until deleted."
echo ""

exit $EXIT_CODE
