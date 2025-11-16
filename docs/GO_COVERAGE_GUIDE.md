# Go Coverage Collection Guide

This guide explains how to collect Go code coverage from the microservices demo.

## Quick Start

### Running Tests with Coverage (Recommended)

```bash
scripts/test-framework/run_local_tests.sh
```

This script:
1. ✅ Runs BDD tests against deployed services
2. ✅ Automatically collects Go coverage after tests complete
3. ✅ Generates HTML and text coverage reports

### Manual Coverage Collection

If you've already run tests and just want to collect coverage:

```bash
scripts/collect-coverage.sh
```

## How It Works

### Architecture

The Go services are built with native coverage instrumentation:

```
Go Service (Running) → SIGUSR1 Signal → Coverage Dump → Coverage Files
                                                             ↓
                                                    Merged & Processed
                                                             ↓
                                                    HTML + Text Reports
```

### Key Features

1. **No Service Shutdown Required**: Coverage is collected via signal (SIGUSR1)
2. **Live Service Coverage**: Services continue running for manual testing
3. **Native Go Coverage**: Uses Go 1.20+ built-in coverage, not test-only coverage
4. **Automatic Merging**: Combines coverage from multiple services

### Services with Coverage

- ✅ **productcatalogservice** - Built with `-cover` flag
- ✅ **checkoutservice** - Built with `-cover` flag
- ✅ **shippingservice** - Built with `-cover` flag

## Coverage Collection Modes

### Mode 1: Local Tests (Port-Forwarding)

**When to use:** Development, debugging, iterative testing

**How it works:**
1. Services run in Kubernetes cluster
2. Tests run on local machine via port-forwarding
3. Coverage collected via `kubectl exec` and `kubectl cp`

**Command:**
```bash
scripts/test-framework/run_local_tests.sh
```

**Pros:**
- Fast test iteration
- Easy debugging with local IDE
- No container rebuilds for test changes

**Cons:**
- Requires kubectl access
- Port-forwarding overhead

### Mode 2: Kubernetes Job

**When to use:** CI/CD, production-like testing

**How it works:**
1. Services run in Kubernetes cluster
2. Tests run as Kubernetes Job (in-cluster)
3. Coverage collected automatically within cluster

**Command:**
```bash
# Deploy with tests in Kubernetes Job mode
make full-ci

# Or retrieve reports manually
scripts/deployment/get_test_reports.sh
```

**Pros:**
- Production-like environment
- No local dependencies (kubectl not required)
- Works in CI/CD pipelines

**Cons:**
- Slower iteration (container rebuild for test changes)
- Harder to debug

## Generated Reports

After running coverage collection, you'll find:

```
test-framework/reports/
├── go-coverage.html          # Interactive HTML with source highlighting
├── go-coverage.txt           # Text format (for tooling)
├── go-coverage-summary.txt   # Package-level percentages
├── go-coverage/              # Raw coverage data
│   ├── productcatalogservice/
│   ├── checkoutservice/
│   ├── shippingservice/
│   └── merged/              # Merged coverage from all services
└── coverage.json            # Trace-based coverage (separate)
```

### Viewing Reports

**HTML Report (Recommended):**
```bash
open test-framework/reports/go-coverage.html
```

**Summary:**
```bash
cat test-framework/reports/go-coverage-summary.txt
```

**Example Output:**
```
github.com/GoogleCloudPlatform/.../productcatalogservice    82.5%
github.com/GoogleCloudPlatform/.../checkoutservice          78.3%
github.com/GoogleCloudPlatform/.../shippingservice          91.2%
---
Total Coverage: 84.0%
```

## Troubleshooting

### Problem: "No coverage data collected"

**Possible causes:**
1. Services not built with coverage instrumentation
2. Services haven't received any requests
3. GOCOVERDIR environment variable not set

**Solution:**
```bash
# Rebuild services with coverage and run tests
make all
```

### Problem: "kubectl command not found"

**Solution:**
Install kubectl:
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Problem: "Pod not found for service"

**Possible causes:**
1. Service not deployed
2. Pod not ready
3. Wrong cluster context

**Solution:**
```bash
# Check if services are running
kubectl get pods

# Check cluster context
kubectl config current-context

# Verify deployment
kubectl get deployment productcatalogservice checkoutservice shippingservice
```

### Problem: "go: command not found"

**Solution:**
Install Go toolchain (required for coverage processing):
```bash
# macOS
brew install go

# Linux
wget https://go.dev/dl/go1.23.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

## Advanced Usage

### Collecting Coverage Without Running Tests

If you've manually tested the services and want to collect coverage:

```bash
# Trigger coverage dump manually
scripts/collect-coverage.sh
```

This is useful for:
- Manual exploratory testing
- Load testing scenarios
- Production-like usage patterns

### Merging Coverage from Multiple Test Runs

```bash
# Run first set of tests
scripts/test-framework/run_local_tests.sh

# Save coverage data
cp -r test-framework/reports/go-coverage /tmp/coverage-run1

# Run different tests
cd test-framework && behave features/other_scenarios.feature && cd ..

# Collect coverage again
scripts/collect-coverage.sh

# Save second run
cp -r test-framework/reports/go-coverage /tmp/coverage-run2

# Merge both runs
go tool covdata merge \
  -i=/tmp/coverage-run1/merged,/tmp/coverage-run2/merged \
  -o=/tmp/coverage-combined

go tool covdata textfmt -i=/tmp/coverage-combined -o=combined-coverage.txt
go tool cover -html=combined-coverage.txt -o=combined-coverage.html
```

### Integration with CI/CD

**GitHub Actions Example:**
```yaml
- name: Run Tests and Collect Coverage
  run: |
    scripts/test-framework/run_local_tests.sh

- name: Upload Coverage Reports
  uses: actions/upload-artifact@v3
  with:
    name: coverage-reports
    path: test-framework/reports/
```

**GitLab CI Example:**
```yaml
test:
  script:
    - scripts/test-framework/run_local_tests.sh
  artifacts:
    paths:
      - test-framework/reports/
    reports:
      coverage_report:
        coverage_format: cobertura
        path: test-framework/reports/go-coverage.txt
```

## Coverage Goals

### Recommended Targets

- **Overall Coverage**: 70-80%
- **Critical Paths**: 90%+ (checkout, payment)
- **Error Handling**: 80%+ (retry logic, fallbacks)

### What Good Coverage Looks Like

✅ **High coverage in:**
- Business logic (product catalog, pricing)
- Request handling (gRPC methods)
- Error handling paths
- Data validation

⚠️ **Lower coverage acceptable in:**
- Generated code (protobuf)
- Simple getters/setters
- Logging statements
- Initialization code

## Related Documentation

- [Test Framework Guide](TEST_FRAMEWORK.md) - Full testing documentation
- [Tracing and Observability](TRACING_AND_OBSERVABILITY.md) - Observability setup
- [Makefile Reference](MAKEFILE_REFERENCE.md) - All available commands
