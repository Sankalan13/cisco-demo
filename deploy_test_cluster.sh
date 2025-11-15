#!/bin/bash

# deploy_test_cluster.sh
# Script to deploy microservices-demo stack onto a kind cluster

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/microservices-demo/release/kubernetes-manifests.yaml"
CLUSTER_NAME="microservices-demo"

# Function to print colored messages
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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
print_info "Checking for required tools..."

REQUIRED_TOOLS=("kind" "kubectl" "docker")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command_exists "$tool"; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    print_error "The following required tools are missing:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Please install the missing tools:"
    echo "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
    echo "  - docker: https://docs.docker.com/get-docker/"
    exit 1
fi

print_success "All required tools are available"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_success "Docker is running"

# Check if the manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    print_error "Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

print_success "Manifest file found: $MANIFEST_FILE"

# Check if a kind cluster already exists
print_info "Checking for existing kind clusters..."
EXISTING_CLUSTERS=$(kind get clusters 2>/dev/null | grep "^${CLUSTER_NAME}$" || true)

if [ -n "$EXISTING_CLUSTERS" ]; then
    print_warning "A kind cluster named '${CLUSTER_NAME}' already exists."
    read -p "Do you want to delete the existing cluster and create a new one? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting existing kind cluster '${CLUSTER_NAME}'..."
        kind delete cluster --name "$CLUSTER_NAME"
        print_success "Cluster deleted"

        print_info "Creating new kind cluster '${CLUSTER_NAME}'..."
        kind create cluster --name "$CLUSTER_NAME"
        print_success "Kind cluster '${CLUSTER_NAME}' created successfully"
    else
        print_info "Using existing kind cluster '${CLUSTER_NAME}'"
        # Set kubectl context to the existing cluster
        kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null 2>&1

        # Check if there are existing deployments
        print_info "Checking for existing deployments in the cluster..."
        EXISTING_DEPLOYMENTS=$(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$EXISTING_DEPLOYMENTS" -gt 0 ]; then
            print_warning "Found $EXISTING_DEPLOYMENTS existing deployment(s) in the cluster."
            kubectl get deployments --all-namespaces
            echo ""
            read -p "Do you want to delete existing deployments before redeploying? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Deleting existing deployments from the manifest..."
                kubectl delete -f "$MANIFEST_FILE" --ignore-not-found=true
                print_success "Existing deployments deleted"
                # Wait a bit for resources to be fully cleaned up
                sleep 5
            else
                print_info "Redeploying without deleting existing resources"
            fi
        fi
    fi
else
    print_info "No existing kind cluster found. Creating new cluster '${CLUSTER_NAME}'..."
    kind create cluster --name "$CLUSTER_NAME"
    print_success "Kind cluster '${CLUSTER_NAME}' created successfully"
fi

# Ensure kubectl context is set correctly
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1

# Deploy the microservices-demo stack
print_info "Deploying microservices-demo stack..."
kubectl apply -f "$MANIFEST_FILE"
print_success "Manifests applied successfully"

# Wait for all deployments to be ready
print_info "Waiting for all deployments to be ready..."
echo ""

# Get list of deployments from the manifest
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
        DESIRED=$(kubectl get deployment "$deployment" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        READY=$(kubectl get deployment "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

        if [ "$DESIRED" != "$READY" ]; then
            ALL_READY=false
            print_info "Deployment '$deployment': $READY/$DESIRED replicas ready"
        fi
    done

    if [ "$ALL_READY" = false ]; then
        sleep $SLEEP_INTERVAL
        ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
        echo ""
    fi
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "Timeout waiting for deployments to be ready"
    echo ""
    print_info "Current deployment status:"
    kubectl get deployments
    exit 1
fi

# Final verification - check all deployments are fully ready
print_info "Verifying all deployments..."
echo ""

ALL_DEPLOYMENTS_READY=true
for deployment in $DEPLOYMENTS; do
    DESIRED=$(kubectl get deployment "$deployment" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    READY=$(kubectl get deployment "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    AVAILABLE=$(kubectl get deployment "$deployment" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

    if [ "$DESIRED" = "$READY" ] && [ "$DESIRED" = "$AVAILABLE" ]; then
        print_success "Deployment '$deployment': $READY/$DESIRED replicas ready"
    else
        print_error "Deployment '$deployment': $READY/$DESIRED replicas ready (Expected: $DESIRED)"
        ALL_DEPLOYMENTS_READY=false
    fi
done

echo ""

if [ "$ALL_DEPLOYMENTS_READY" = true ]; then
    print_success "========================================="
    print_success "All services have been deployed successfully!"
    print_success "========================================="
    echo ""
    print_info "Deployment summary:"
    kubectl get deployments
    echo ""
    print_info "Services:"
    kubectl get services
    echo ""
    print_info "To access the frontend service, you may need to port-forward:"
    echo "  kubectl port-forward svc/frontend 8080:80"
    echo ""
    exit 0
else
    print_error "Some deployments are not ready. Please check the logs."
    echo ""
    kubectl get deployments
    exit 1
fi
