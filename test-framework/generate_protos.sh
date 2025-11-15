#!/bin/bash

# generate_protos.sh
# Generate Python gRPC code from proto files in microservices-demo

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_DIR="$SCRIPT_DIR/../microservices-demo/protos"
OUTPUT_DIR="$SCRIPT_DIR/generated"

print_info "Generating Python gRPC code from proto files..."

# Check if proto directory exists
if [ ! -d "$PROTO_DIR" ]; then
    print_error "Proto directory not found: $PROTO_DIR"
    exit 1
fi

# Check if python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 not found. Please install Python 3.8 or higher."
    exit 1
fi

# Check if grpc_tools are available
# NOTE: We use grpc_tools.protoc which bundles its own protoc compiler
# System protoc is NOT required - grpcio-tools provides everything needed
if ! python3 -c "import grpc_tools" 2>/dev/null; then
    print_error "grpc_tools not found. Please install dependencies:"
    echo "  pip3 install -r requirements.txt"
    echo ""
    echo "Note: grpcio-tools bundles a compatible protoc compiler,"
    echo "      so system protoc installation is NOT required."
    exit 1
fi

# Get grpc_tools version for informational purposes
GRPCIO_TOOLS_VERSION=$(python3 -c "import grpc_tools; print(grpc_tools.__version__)" 2>/dev/null || echo "unknown")
print_info "Using grpcio-tools version: $GRPCIO_TOOLS_VERSION"
print_info "Using bundled protoc from grpcio-tools (system protoc not required)"

# Clean and create output directory
print_info "Cleaning output directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create __init__.py to make it a Python package
touch "$OUTPUT_DIR/__init__.py"

# Generate code from demo.proto
print_info "Generating code from demo.proto..."
python3 -m grpc_tools.protoc \
    -I"$PROTO_DIR" \
    --python_out="$OUTPUT_DIR" \
    --grpc_python_out="$OUTPUT_DIR" \
    "$PROTO_DIR/demo.proto"

if [ $? -eq 0 ]; then
    print_success "Generated demo_pb2.py and demo_pb2_grpc.py"
else
    print_error "Failed to generate code from demo.proto"
    exit 1
fi

# Generate code from health.proto
print_info "Generating code from health.proto..."
python3 -m grpc_tools.protoc \
    -I"$PROTO_DIR" \
    --python_out="$OUTPUT_DIR" \
    --grpc_python_out="$OUTPUT_DIR" \
    "$PROTO_DIR/grpc/health/v1/health.proto"

if [ $? -eq 0 ]; then
    print_success "Generated health_pb2.py and health_pb2_grpc.py"
else
    print_error "Failed to generate code from health.proto"
    exit 1
fi

# Fix import paths in generated files (grpc.health.v1 -> generated.grpc.health.v1)
print_info "Fixing import paths in generated files..."

# Create nested package structure for health
mkdir -p "$OUTPUT_DIR/grpc/health/v1"
touch "$OUTPUT_DIR/grpc/__init__.py"
touch "$OUTPUT_DIR/grpc/health/__init__.py"
touch "$OUTPUT_DIR/grpc/health/v1/__init__.py"

# Move health proto files to proper location
if [ -f "$OUTPUT_DIR/health_pb2.py" ]; then
    mv "$OUTPUT_DIR/health_pb2.py" "$OUTPUT_DIR/grpc/health/v1/"
fi
if [ -f "$OUTPUT_DIR/health_pb2_grpc.py" ]; then
    mv "$OUTPUT_DIR/health_pb2_grpc.py" "$OUTPUT_DIR/grpc/health/v1/"
fi

# Fix import paths in generated grpc files
print_info "Fixing import paths in generated grpc files..."

# Fix demo_pb2_grpc.py: import demo_pb2 -> from generated import demo_pb2
if [ -f "$OUTPUT_DIR/demo_pb2_grpc.py" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/^import demo_pb2 as demo__pb2/from generated import demo_pb2 as demo__pb2/g' "$OUTPUT_DIR/demo_pb2_grpc.py"
    else
        # Linux
        sed -i 's/^import demo_pb2 as demo__pb2/from generated import demo_pb2 as demo__pb2/g' "$OUTPUT_DIR/demo_pb2_grpc.py"
    fi
fi

# Fix health_pb2_grpc.py: from grpc.health.v1 -> from generated.grpc.health.v1
if [ -f "$OUTPUT_DIR/grpc/health/v1/health_pb2_grpc.py" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/from grpc\.health\.v1 import health_pb2/from generated.grpc.health.v1 import health_pb2/g' "$OUTPUT_DIR/grpc/health/v1/health_pb2_grpc.py"
    else
        # Linux
        sed -i 's/from grpc\.health\.v1 import health_pb2/from generated.grpc.health.v1 import health_pb2/g' "$OUTPUT_DIR/grpc/health/v1/health_pb2_grpc.py"
    fi
fi

print_success "Import paths fixed"

print_success "Proto code generation complete!"
print_info "Generated files in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.py 2>/dev/null || true
ls -lh "$OUTPUT_DIR/grpc/health/v1"/*.py 2>/dev/null || true

echo ""
print_success "✓ Ready to use generated gRPC clients"
