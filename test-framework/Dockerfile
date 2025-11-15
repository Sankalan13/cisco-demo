# Multi-stage Dockerfile for Test Framework
# Builds a containerized test environment with all dependencies and proto code pre-generated

FROM python:3.12-slim AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy requirements and install grpcio-tools for proto generation
# IMPORTANT: Use same versions as runtime to avoid protobuf version mismatch
COPY test-framework/requirements.txt /build/
RUN pip install --no-cache-dir grpcio-tools==1.68.1 protobuf==5.29.1

# Copy proto files from parent directory structure
# NOTE: This Dockerfile expects to be built from the project root with:
#   docker build -f test-framework/Dockerfile -t test-framework:latest .
# This allows access to microservices-demo/protos/ via the build context
COPY microservices-demo/protos/ /build/protos/

# Generate Python gRPC code from proto files directly
RUN mkdir -p /build/generated && \
    touch /build/generated/__init__.py && \
    python3 -m grpc_tools.protoc \
        -I/build/protos \
        --python_out=/build/generated \
        --grpc_python_out=/build/generated \
        /build/protos/demo.proto && \
    mkdir -p /build/generated/grpc/health/v1 && \
    touch /build/generated/grpc/__init__.py && \
    touch /build/generated/grpc/health/__init__.py && \
    touch /build/generated/grpc/health/v1/__init__.py && \
    python3 -m grpc_tools.protoc \
        -I/build/protos \
        --python_out=/build/generated \
        --grpc_python_out=/build/generated \
        /build/protos/grpc/health/v1/health.proto && \
    mv /build/generated/health_pb2.py /build/generated/grpc/health/v1/ 2>/dev/null || true && \
    mv /build/generated/health_pb2_grpc.py /build/generated/grpc/health/v1/ 2>/dev/null || true && \
    sed -i 's/^import demo_pb2 as demo__pb2/from generated import demo_pb2 as demo__pb2/g' /build/generated/demo_pb2_grpc.py 2>/dev/null || true && \
    sed -i 's/from grpc\.health\.v1 import health_pb2/from generated.grpc.health.v1 import health_pb2/g' /build/generated/grpc/health/v1/health_pb2_grpc.py 2>/dev/null || true

# Final stage
FROM python:3.12-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install Python dependencies
COPY test-framework/requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY test-framework/config/ /app/config/
COPY test-framework/features/ /app/features/
COPY test-framework/utils/ /app/utils/
COPY test-framework/behave.ini /app/
COPY test-framework/generate_coverage.py /app/
COPY test-framework/entrypoint.sh /app/

# Copy pre-generated proto code from builder stage
COPY --from=builder /build/generated/ /app/generated/

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Create reports directory
RUN mkdir -p /app/reports

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    TEST_MODE=kubernetes \
    PYTHONPATH=/app

# Default command (can be overridden)
ENTRYPOINT ["/app/entrypoint.sh"]
