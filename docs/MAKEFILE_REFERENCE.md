# Makefile Reference

Complete reference for all Make targets in the microservices-demo project.

## Quick Start

```bash
# Full workflow (recommended for first run)
make all

# Fast iteration during development
make quick

# CI/CD mode
make full-ci
```

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLUSTER_NAME` | `microservices-demo` | Kind cluster name |
| `TEST_MODE` | `local` | Test execution mode (`local` or `k8s`) |
| `AUTO_APPROVE` | `1` | Auto-approve destructive actions (0=interactive) |

### Examples

```bash
# Use custom cluster name
make cluster CLUSTER_NAME=my-cluster

# Run tests in K8s Job mode
make test TEST_MODE=k8s

# Interactive mode (prompts for confirmations)
make deploy AUTO_APPROVE=0
```

## Complete Workflows

### `make all`
**Full local workflow:** Build → Deploy → Test → Coverage

Steps:
1. Build all Docker images (Go + Node.js)
2. Create Kind cluster (if needed)
3. Load images into cluster
4. Deploy services with Kustomize
5. Start port-forwards
6. Run tests locally
7. Generate coverage reports

**Time:** ~5-10 minutes (first run), ~2-3 minutes (cached)

### `make quick`
**Fast iteration workflow:** Skip builds, fast deploy

Use when:
- Images already built
- Quick test iteration
- Debugging tests

**Time:** ~1-2 minutes

### `make full-ci`
**CI/CD workflow:** Clean start, K8s test mode

Steps:
1. Clean all artifacts
2. Create fresh cluster
3. Build all images
4. Deploy services
5. Run tests as K8s Job
6. Generate coverage

**Time:** ~8-12 minutes

## Build Targets

### `make build`
Build all Docker images (Go services + Node.js services)

**Output:** `.build/*-local-coverage`, `.build/*-local-fixed`

### `make build-go-images`
Build only Go services with coverage instrumentation
- productcatalogservice
- checkoutservice
- shippingservice

### `make build-node-images`
Build only Node.js services with OTel fixes
- currencyservice
- paymentservice

### `make rebuild`
Force rebuild all images (ignores cache)

### `make clean-images`
Remove all built Docker images

## Cluster Management

### `make cluster`
Create Kind cluster (alias for `cluster-create`)

### `make cluster-create`
Create Kind cluster if it doesn't exist

**Behavior:**
- If cluster exists and `AUTO_APPROVE=1`: Use existing
- If cluster exists and `AUTO_APPROVE=0`: Prompt to recreate
- If cluster doesn't exist: Create new

### `make cluster-delete`
Delete Kind cluster and all related artifacts

**Warning:** Destroys cluster, images-loaded state, and deployment state

### `make cluster-status`
Show cluster information and node status

### `make cluster-exists`
Check if cluster exists (exit code 0=yes, 1=no)

## Deployment

### `make deploy`
Deploy all services to Kind cluster

**Prerequisites:**
- Cluster created
- Images loaded

**Steps:**
1. Apply Kustomize manifests
2. Wait for deployments (timeout: 600s)

### `make load-images`
Load Docker images into Kind cluster

**Note:** Automatically called by `deploy`

### `make wait-deployments`
Wait for all deployments to be ready

### `make undeploy`
Remove all deployed resources

### `make deployment-status`
Show deployment, pod, and service status

## Testing

### `make test`
Run tests (mode determined by `TEST_MODE` variable)

**Local mode** (default):
```bash
make test              # or make test TEST_MODE=local
```
- Starts port-forwards
- Runs Behave tests from host machine
- Collects coverage in real-time

**K8s Job mode**:
```bash
make test TEST_MODE=k8s
```
- Builds test-framework image
- Deploys as Kubernetes Job
- Retrieves reports from PVC

### `make test-local`
Explicitly run tests in local mode

### `make test-k8s`
Explicitly run tests in K8s Job mode

### `make generate-protos`
Generate Python protobuf code

**When needed:**
- After modifying .proto files
- First time setup

### `make clean-test-reports`
Clean test reports directory

## Coverage

### `make coverage`
Generate all coverage reports (trace + Go code)

**Outputs:**
- `test-framework/reports/coverage.json` (trace coverage)
- `test-framework/reports/go-coverage-*.html` (Go code coverage)

### `make generate-trace-coverage`
Generate coverage from Jaeger traces

**Prerequisites:**
- Tests have run
- `test_execution_time.json` exists

### `make collect-go-coverage`
Collect Go code coverage from services

**Method:**
1. Send SIGUSR1 to Go pods (triggers coverage dump)
2. kubectl cp coverage files from pods
3. Process with go tool covdata

### `make coverage-summary`
Display coverage summary in terminal

### `make clean-coverage`
Remove all coverage reports

## Proto Generation

### `make proto-all`
Generate all protobuf code (Go + Python)

### `make proto-go`
Generate Go protobuf code for all services

**Services:**
- productcatalogservice, checkoutservice, emailservice
- currencyservice, paymentservice, shippingservice
- adservice, frontend, recommendationservice

### `make proto-python`
Generate Python protobuf code (test framework)

### `make proto-clean`
Remove all generated protobuf code

## Port Forwarding

### `make port-forward`
Start kubectl port-forwards (alias for `port-forward-start`)

### `make port-forward-start`
Start port-forwards in background

**Services exposed:**
- Product Catalog: localhost:3550
- Cart Service: localhost:7070
- Currency: localhost:7000
- Recommendation: localhost:8080
- Checkout: localhost:5050
- Payment: localhost:50051
- Shipping: localhost:50052
- Email: localhost:5000
- Ad Service: localhost:9555
- Jaeger UI: http://localhost:16686

### `make port-forward-stop`
Stop all port-forwards

### `make port-forward-status`
Show port-forward status

## Utilities

### `make logs`
Tail logs from all pods

### `make status`
Show overall system status (cluster + deployments)

### `make shell`
Open debug shell in cluster

## Cleanup

### `make clean`
Clean build artifacts (.build/, generated/, reports/)

**Safe:** Does not affect cluster or images

### `make clean-all`
Nuclear option: Delete everything

**Steps:**
1. Stop port-forwards
2. Delete cluster
3. Remove build artifacts
4. Remove Docker images
5. Clean coverage reports

**Warning:** Complete reset, ~10 minutes to rebuild

## Dependency Graph

```
all
├── build
│   ├── build-go-images
│   │   └── .build/*-local-coverage
│   └── build-node-images
│       └── .build/*-local-fixed
├── deploy
│   ├── .build/cluster-created
│   └── .build/images-loaded
│       ├── cluster-create
│       └── build-images
├── test-local
│   ├── deploy
│   ├── port-forward-start
│   └── generate-protos
└── coverage
    ├── generate-trace-coverage
    └── collect-go-coverage
```

## Parallel Execution

Make supports parallel execution:

```bash
# Build all images in parallel (8 jobs)
make -j8 build

# Parallel proto generation
make -j9 proto-go
```

**Recommended:**
- `-j4` for laptops
- `-j8` for desktops
- `-j$(nproc)` for servers

## Troubleshooting

### Build failures

```bash
# Force rebuild
make clean-images rebuild

# Check Docker
docker info
```

### Cluster issues

```bash
# Check cluster
make cluster-status

# Recreate cluster
make cluster-delete cluster-create
```

### Test failures

```bash
# Check logs
make logs

# Check deployments
make deployment-status

# Restart port-forwards
make port-forward-stop port-forward-start
```

### Coverage issues

```bash
# Verify Jaeger
kubectl get pods | grep jaeger

# Check coverage files exist
ls -la test-framework/reports/
```

## Advanced Usage

### Custom workflows

Create custom targets in top-level Makefile:

```makefile
.PHONY: my-workflow
my-workflow: build deploy
	@echo "Running custom workflow..."
	# Custom commands here
```

### Conditional execution

```makefile
deploy-prod:
	@if [ "$(CLUSTER_NAME)" = "production" ]; then \
		echo "ERROR: Don't deploy to production!"; \
		exit 1; \
	fi
	@$(MAKE) deploy
```

### Override variables

```bash
# Temporary override
make test CLUSTER_NAME=test-cluster

# Environment variable (persistent in session)
export CLUSTER_NAME=test-cluster
make test
```

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Run tests
  run: make full-ci
```

### GitLab CI

```yaml
test:
  script:
    - make full-ci
```

### Jenkins

```groovy
stage('Test') {
    steps {
        sh 'make full-ci'
    }
}
```
