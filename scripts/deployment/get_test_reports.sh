#!/bin/bash
#
# get_test_reports.sh
# Extracts test reports from Kubernetes PVC to local filesystem

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
REPORTS_DIR="$TEST_FRAMEWORK_DIR/reports"
CLUSTER_NAME="microservices-demo"

echo ""
print_info "========================================="
print_info "Test Reports Retrieval"
print_info "========================================="
echo ""

# Step 1: Verify kubectl context
print_info "Step 1: Verifying Kubernetes context..."

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "Failed to set kubectl context to 'kind-${CLUSTER_NAME}'"
    print_error "Is the cluster running?"
    exit 1
fi

print_success "Context set to 'kind-${CLUSTER_NAME}'"
echo ""

# Step 2: Verify PVC exists
print_info "Step 2: Verifying PVC 'test-reports' exists..."

if ! kubectl get pvc test-reports >/dev/null 2>&1; then
    print_error "PVC 'test-reports' not found"
    print_error "Have you run the tests yet? (./deploy_test_runner.sh)"
    exit 1
fi

print_success "PVC found"
echo ""

# Step 3: Create temporary pod to access PVC
print_info "Step 3: Creating temporary pod to access PVC..."

POD_NAME="test-reports-retriever"

# Delete existing pod if it exists
if kubectl get pod "$POD_NAME" >/dev/null 2>&1; then
    print_info "Deleting existing retriever pod..."
    kubectl delete pod "$POD_NAME" --timeout=30s || true
    sleep 2
fi

# Create temporary pod with PVC mounted
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: default
spec:
  containers:
  - name: retriever
    image: busybox:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: reports
      mountPath: /reports
  volumes:
  - name: reports
    persistentVolumeClaim:
      claimName: test-reports
  restartPolicy: Never
EOF

print_success "Temporary pod created"
echo ""

# Step 4: Wait for pod to be ready
print_info "Step 4: Waiting for pod to be ready..."

kubectl wait --for=condition=Ready pod/"$POD_NAME" --timeout=60s

print_success "Pod is ready"
echo ""

# Step 5: List available reports
print_info "Step 5: Listing available reports in PVC..."

kubectl exec "$POD_NAME" -- ls -lh /reports || true

echo ""

# Step 6: Create local reports directory
print_info "Step 6: Preparing local reports directory..."

mkdir -p "$REPORTS_DIR"

# Backup existing reports if any
if [ "$(ls -A $REPORTS_DIR 2>/dev/null)" ]; then
    BACKUP_DIR="$REPORTS_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    print_info "Backing up existing reports to: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp -r "$REPORTS_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    rm -rf "$REPORTS_DIR"/*.json "$REPORTS_DIR"/*.xml 2>/dev/null || true
fi

print_success "Local directory ready: $REPORTS_DIR"
echo ""

# Step 7: Copy reports from PVC to local filesystem
print_info "Step 7: Copying reports from PVC to local filesystem..."

# Use kubectl cp to copy entire reports directory
kubectl cp "default/$POD_NAME:/reports/." "$REPORTS_DIR/"

if [ $? -ne 0 ]; then
    print_warning "Some files may not have been copied (this is normal if no reports exist yet)"
else
    print_success "Reports copied successfully"
fi

echo ""

# Step 8: Display report summary
print_info "Step 8: Report Summary"

# Generate Go coverage summary locally if not present but coverage data exists
if [ ! -f "$REPORTS_DIR/go-coverage-summary.txt" ] && [ -d "$REPORTS_DIR/go-coverage" ]; then
    print_info "Generating Go coverage summary from retrieved coverage data..."

    # Build coverage inputs list
    COVERAGE_INPUTS=""
    for service_dir in "$REPORTS_DIR/go-coverage/"*/; do
        if [ -d "$service_dir" ] && ls "$service_dir"cov* >/dev/null 2>&1; then
            if [ -z "$COVERAGE_INPUTS" ]; then
                COVERAGE_INPUTS="$service_dir"
            else
                COVERAGE_INPUTS="$COVERAGE_INPUTS,$service_dir"
            fi
        fi
    done

    # Generate summary if we have coverage data
    if [ -n "$COVERAGE_INPUTS" ]; then
        if command -v go >/dev/null 2>&1; then
            go tool covdata percent -i="$COVERAGE_INPUTS" > "$REPORTS_DIR/go-coverage-summary.txt" 2>/dev/null || \
                print_warning "Failed to generate Go coverage summary"
        else
            print_warning "Go toolchain not found, cannot generate coverage summary"
        fi
    fi
fi

echo ""
echo "========================================"
echo "Behave Test Summary:"
echo "========================================"

# Display Behave summary if available
if [ -f "$REPORTS_DIR/behave_output.txt" ]; then
    tail -5 "$REPORTS_DIR/behave_output.txt" | grep -E "(features|scenarios|steps|Took)" || echo "Behave summary not available in output"
else
    echo "Behave output not found"
fi

echo ""
echo "========================================"
echo "Golang Coverage Summary:"
echo "========================================"

# Display Go coverage summary if available
if [ -f "$REPORTS_DIR/go-coverage-summary.txt" ]; then
    cat "$REPORTS_DIR/go-coverage-summary.txt"
else
    echo "Go coverage not available"
fi

echo ""
echo "========================================"
echo "Coverage Metrics"
echo "========================================"

# Display trace coverage summary if available
if [ -f "$REPORTS_DIR/coverage.json" ]; then
    python3 << EOF
import json
import sys
try:
    with open('$REPORTS_DIR/coverage.json') as f:
        report = json.load(f)
    summary = report.get('summary', {})
    print(f"  Total Services: {summary.get('total_services', 0)}")
    print(f"  Covered Services: {summary.get('covered_services', 0)}")
    print(f"  Service Coverage: {summary.get('service_coverage_percentage', 0.0)}%")
    print(f"  Total Methods: {summary.get('total_methods', 0)}")
    print(f"  Covered Methods: {summary.get('covered_methods', 0)}")
    print(f"  Method Coverage: {summary.get('method_coverage_percentage', 0.0)}%")
except Exception as e:
    print(f"  Error reading coverage report: {e}")
    sys.exit(0)
EOF
else
    echo "  Coverage metrics not available"
fi

echo ""
echo "========================================"
echo "Reports"
echo "========================================"
echo "  Location: $REPORTS_DIR/"
echo "  - Behave output: behave_output.txt"
echo "  - JUnit XML: TESTS-*.xml"
echo "  - Trace coverage: coverage.json"
echo "  - Go coverage: go-coverage-*.html"
echo "========================================"
echo ""

# List local reports
if [ "$(ls -A $REPORTS_DIR 2>/dev/null)" ]; then
    print_info "Local reports directory: $REPORTS_DIR"
    ls -lh "$REPORTS_DIR/" | head -20
    echo ""
else
    print_warning "No reports found in PVC"
    print_info "The test-runner Job may not have completed yet, or no tests have been run."
fi

# Step 9: Cleanup temporary pod
print_info "Step 9: Cleaning up temporary pod..."

kubectl delete pod "$POD_NAME" --timeout=60s --wait=false

# Give it a moment to start deletion, but don't wait for completion
sleep 1

print_success "Temporary pod deletion initiated"
echo ""

print_success "========================================="
print_success "Report retrieval complete!"
print_success "========================================="
echo ""
print_info "Reports are now available in: $REPORTS_DIR"
echo ""

exit 0
