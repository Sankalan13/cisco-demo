# Kubernetes Test Deployment Guide

This guide explains how to run the BDD test framework as a Kubernetes Job, enabling in-cluster testing without port-forwarding.

## Overview

The test framework supports two execution modes:

1. **Local Mode** (default) - Tests run on your local machine with port-forwarding to Kubernetes services
2. **Kubernetes Mode** - Tests run as a Kubernetes Job inside the cluster using native service DNS

## Architecture

### Local Mode Architecture
```
[Local Machine]
    └── Test Framework (Python/Behave)
        └── Port-Forwards (kubectl)
            └── [Kubernetes Cluster]
                ├── Microservices (productcatalog, cart, etc.)
                ├── OTel Collector
                └── Jaeger
```

### Kubernetes Mode Architecture
```
[Kubernetes Cluster]
    ├── Test Runner Job
    │   └── Test Framework Container
    │       └── Direct service calls (DNS: productcatalogservice:3550)
    ├── Microservices (productcatalog, cart, etc.)
    ├── OTel Collector
    ├── Jaeger
    └── PersistentVolume (test reports storage)
```

## Prerequisites

- Kind cluster deployed with microservices
- Docker installed (for building test framework image)
- kubectl configured with correct context

## Quick Start

### Option 1: Integrated Deployment (Recommended)

Deploy cluster, services, AND tests all together:

```bash
# From project root
./run_all.sh --deploy-tests
```

This will:
1. Build all Docker images
2. Create Kind cluster
3. Deploy microservices with tracing
4. Build and deploy test framework as Kubernetes Job
5. Stream Job logs
6. Retrieve test reports automatically

### Option 2: Manual Deployment

If you already have a cluster running with services deployed:

```bash
# Build and deploy test Job
scripts/deployment/deploy_test_runner.sh

# Retrieve reports after Job completes
scripts/deployment/get_test_reports.sh
```

## Configuration

### Dual-Mode Configuration

The test framework automatically detects execution mode via the `TEST_MODE` environment variable:

- **Local Mode**: `TEST_MODE=local` (default) → uses `config/services.yaml`
  - Service endpoints: `localhost:PORT`
  - Example: `productcatalogservice` → `localhost:3550`

- **Kubernetes Mode**: `TEST_MODE=kubernetes` → uses `config/services-k8s.yaml`
  - Service endpoints: `SERVICENAME:PORT`
  - Example: `productcatalogservice` → `productcatalogservice:3550`

### Configuration Files

#### `config/services.yaml` (Local Mode)
```yaml
services:
  productcatalog:
    host: localhost  # Port-forwarded endpoint
    port: 3550
```

#### `config/services-k8s.yaml` (Kubernetes Mode)
```yaml
services:
  productcatalog:
    host: productcatalogservice  # Kubernetes service DNS
    port: 3550
```

The `config_loader.py` automatically selects the correct configuration based on `TEST_MODE`.

## Components

### 1. Dockerfile

Multi-stage build that:
- Generates proto code at build time (faster container startup)
- Installs all Python dependencies
- Copies test framework code
- Sets default environment variables

**Key features:**
- Base image: `python:3.12-slim`
- Proto generation in builder stage
- Minimal runtime dependencies
- Pre-configured for Kubernetes mode

### 2. Kubernetes Resources

#### RBAC (`test-runner-rbac.yaml`)
- **ServiceAccount**: `test-runner`
- **Role**: Minimal permissions (get/list services and pods)
- **RoleBinding**: Binds role to service account

#### PersistentVolumeClaim (`test-reports-pvc.yaml`)
- **Name**: `test-reports`
- **Storage**: 1Gi
- **Access Mode**: ReadWriteOnce
- **Purpose**: Persists test reports and coverage data

#### Job (`test-runner-job.yaml`)
- **Name**: `test-runner`
- **Restart Policy**: Never (one-time execution)
- **TTL**: 3600 seconds (auto-cleanup after 1 hour)
- **Resources**:
  - Requests: 500m CPU, 512Mi memory
  - Limits: 1000m CPU, 1Gi memory
- **Environment Variables**:
  - `TEST_MODE=kubernetes`
  - `OTEL_COLLECTOR_ENDPOINT=opentelemetrycollector:4317`
  - `JAEGER_ENDPOINT=jaeger-query:16686`

### 3. Deployment Scripts

#### `deploy_test_runner.sh`
Automated deployment script that:
1. Verifies Kind cluster exists
2. Builds Docker image (`test-framework:latest`)
3. Loads image into Kind cluster
4. Applies RBAC configuration
5. Creates/verifies PVC
6. Deploys Job
7. Streams Job logs in real-time
8. Reports Job completion status

**Usage:**
```bash
scripts/deployment/deploy_test_runner.sh
```

#### `get_test_reports.sh`
Report retrieval script that:
1. Creates temporary pod with PVC mounted
2. Copies reports from PVC to local filesystem
3. Displays coverage summary
4. Cleans up temporary pod

**Usage:**
```bash
scripts/deployment/get_test_reports.sh
```

**Reports retrieved:**
- `coverage.json` - Service and method coverage metrics
- `TESTS-*.xml` - JUnit XML test reports
- `test_execution_time.json` - Test execution time window

### 4. Container Entrypoint

The `entrypoint.sh` script runs inside the Job container:

**Execution flow:**
1. Verify configuration file exists
2. Run Behave tests with JUnit output
3. Flush OpenTelemetry spans (via `environment.py`)
4. Wait for traces to propagate to Jaeger (5 seconds)
5. Generate coverage report from Jaeger traces
6. Display summary metrics
7. Keep container alive briefly for log collection (10 seconds)
8. Exit with test result code

## Usage Examples

### Example 1: Full Workflow (Local to Kubernetes)

```bash
# Step 1: Deploy cluster and services
./run_all.sh

# Step 2: Run tests locally (with port-forwarding)
cd test-framework
behave features/

# Step 3: Deploy tests to Kubernetes
cd deploy_scripts
./deploy_test_runner.sh

# Step 4: Retrieve reports
./get_test_reports.sh
```

### Example 2: CI/CD Pipeline

```bash
# In your CI/CD pipeline (e.g., GitHub Actions, GitLab CI)

# Deploy infrastructure
./run_all.sh --deploy-tests

# Reports are automatically retrieved to test-framework/reports/
# Publish JUnit XML reports
- test-framework/reports/TESTS-*.xml

# Publish coverage JSON
- test-framework/reports/coverage.json
```

### Example 3: Iterative Testing

```bash
# Deploy once
./run_all.sh

# Iterate on tests
cd test-framework

# Edit test code
vim features/product_browsing.feature

# Rebuild and redeploy
cd deploy_scripts
./deploy_test_runner.sh  # Automatically rebuilds image

# Get results
./get_test_reports.sh
```

## Troubleshooting

### Job Fails to Start

**Symptoms:**
- Job pod stuck in `Pending` or `ImagePullBackOff` state

**Solutions:**
```bash
# Check pod status
kubectl get pods -l job-name=test-runner

# Describe pod for events
kubectl describe pod -l job-name=test-runner

# Verify image is loaded into Kind
docker exec -it microservices-demo-control-plane crictl images | grep test-framework

# Reload image if needed
kind load docker-image test-framework:latest --name microservices-demo
```

### Tests Fail with Connection Errors

**Symptoms:**
- Tests report "failed to connect to service" errors
- gRPC connection timeouts

**Solutions:**
```bash
# Verify services are running
kubectl get svc

# Check service endpoints
kubectl get endpoints productcatalogservice

# Verify DNS resolution from within cluster
kubectl run debug --rm -it --image=busybox --restart=Never -- nslookup productcatalogservice

# Check logs for specific errors
kubectl logs -l job-name=test-runner
```

### Coverage Report Empty

**Symptoms:**
- `coverage.json` shows 0 services covered
- No traces in Jaeger

**Solutions:**
```bash
# Verify OTel Collector is running
kubectl get pods -l app=opentelemetrycollector

# Check OTel Collector logs
kubectl logs -l app=opentelemetrycollector

# Verify Jaeger is running
kubectl get pods -l app=jaeger

# Port-forward Jaeger UI and inspect traces manually
kubectl port-forward svc/jaeger-query 16686:16686
# Visit http://localhost:16686
```

### PVC Issues

**Symptoms:**
- Pod stuck in `Pending` due to PVC binding issues
- Cannot retrieve reports

**Solutions:**
```bash
# Check PVC status
kubectl get pvc test-reports

# Check PV binding
kubectl get pv

# Delete and recreate PVC
kubectl delete pvc test-reports
kubectl apply -f test-reports-pvc.yaml

# Verify storage class exists
kubectl get storageclass
```

### Logs Not Appearing

**Symptoms:**
- `kubectl logs` shows no output or incomplete output

**Solutions:**
```bash
# Wait for pod to be running
kubectl wait --for=condition=Ready pod -l job-name=test-runner --timeout=60s

# Stream logs (follow mode)
kubectl logs -f -l job-name=test-runner

# Check container status
kubectl describe pod -l job-name=test-runner
```

## Comparison: Local vs Kubernetes Mode

| Feature | Local Mode | Kubernetes Mode |
|---------|-----------|----------------|
| **Execution Location** | Your local machine | Inside Kubernetes cluster |
| **Service Access** | Port-forwarding required | Native Kubernetes DNS |
| **Network Latency** | Higher (port-forward overhead) | Lower (in-cluster) |
| **Configuration** | `services.yaml` | `services-k8s.yaml` |
| **Setup Time** | Faster (no image build) | Slower (Docker build required) |
| **CI/CD Integration** | Requires port-forwarding setup | Native Kubernetes Job |
| **Report Storage** | Local filesystem | PersistentVolume + retrieval |
| **Debugging** | Easier (local logs) | Requires kubectl logs |
| **Resource Usage** | Local machine resources | Cluster resources (limited by requests/limits) |
| **Scalability** | Limited to local machine | Can run multiple Jobs in parallel |

## Best Practices

### 1. Image Management

- **Tag images appropriately** for different environments:
  ```bash
  docker build -t test-framework:v1.0.0 .
  docker build -t test-framework:latest .
  ```

- **Use specific tags in production**:
  ```yaml
  # test-runner-job.yaml
  image: test-framework:v1.0.0  # Not :latest
  ```

### 2. Resource Limits

Adjust based on your test complexity:

```yaml
# For small test suites
resources:
  requests: {cpu: 250m, memory: 256Mi}
  limits: {cpu: 500m, memory: 512Mi}

# For large test suites
resources:
  requests: {cpu: 1000m, memory: 1Gi}
  limits: {cpu: 2000m, memory: 2Gi}
```

### 3. PVC Cleanup

Regularly clean up old reports to avoid filling the PVC:

```bash
# Delete PVC (will delete all reports)
kubectl delete pvc test-reports

# Recreate fresh PVC
kubectl apply -f test-reports-pvc.yaml
```

### 4. Job Cleanup

Configure TTL for automatic cleanup:

```yaml
# test-runner-job.yaml
spec:
  ttlSecondsAfterFinished: 3600  # Delete after 1 hour
```

Or manually delete Jobs:

```bash
# Delete completed Job
kubectl delete job test-runner

# Delete all test-runner Jobs
kubectl delete jobs -l app=test-runner
```

### 5. Debugging Tips

**Enable verbose logging:**

Modify `entrypoint.sh` to add verbose flags:
```bash
behave /app/features/ -v --no-capture  # See all logs
```

**Access Job pod directly:**
```bash
# Get pod name
POD=$(kubectl get pods -l job-name=test-runner -o jsonpath='{.items[0].metadata.name}')

# Exec into pod (if still running)
kubectl exec -it $POD -- /bin/bash

# Check generated reports
kubectl exec $POD -- ls -la /app/reports/
```

**Extract files without get_test_reports.sh:**
```bash
POD=$(kubectl get pods -l job-name=test-runner -o jsonpath='{.items[0].metadata.name}')
kubectl cp default/$POD:/app/reports/coverage.json ./coverage.json
```

## Advanced Topics

### Running Tests in Parallel

Create multiple Job instances with different test subsets:

```yaml
# test-runner-job-feature1.yaml
metadata:
  name: test-runner-feature1
spec:
  template:
    spec:
      containers:
        - name: test-runner
          command: ["/app/entrypoint.sh"]
          args: ["/app/features/product_browsing.feature"]

# test-runner-job-feature2.yaml
metadata:
  name: test-runner-feature2
spec:
  template:
    spec:
      containers:
        - name: test-runner
          command: ["/app/entrypoint.sh"]
          args: ["/app/features/checkout.feature"]
```

### Custom Configuration Injection

Use ConfigMaps to inject custom service configurations:

```bash
# Create ConfigMap from custom config
kubectl create configmap test-config --from-file=services-k8s.yaml=my-custom-config.yaml

# Mount in Job
volumeMounts:
  - name: config
    mountPath: /app/config/services-k8s.yaml
    subPath: services-k8s.yaml
volumes:
  - name: config
    configMap:
      name: test-config
```

### Integration with GitOps

Example ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-runner
spec:
  source:
    path: scripts/deployment
    targetRevision: main
  destination:
    namespace: default
  sync Policy:
    automated:
      prune: true
      selfHeal: true
```

## Conclusion

The Kubernetes deployment mode enables:
- ✅ Scalable, in-cluster testing
- ✅ CI/CD pipeline integration
- ✅ Realistic network conditions (no port-forwarding overhead)
- ✅ Automated report persistence and retrieval
- ✅ Resource-controlled test execution

Choose **Local Mode** for rapid iteration and debugging.
Choose **Kubernetes Mode** for CI/CD pipelines and production-like testing.
