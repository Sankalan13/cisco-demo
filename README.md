# System Tests for Google Microservices Demo

This repository is responsible for running end to end system tests on the google microservices demo repository on fix version v0.10.3 as main repo is broken. The test strategy involves testing user life cycle workflows via gRPC calls to the backend services and using OpenTelemetry and Jager to capture trace coverage of the tests. We also generate golang services coverage report using the golang coverprofile directly from running containers. 

# Documentation Index

This file contains all documentation for the microservices-demo testing framework.

## Quick Links

### Getting Started
- [Main README](../README.md) - Project overview and quick start guide
- [Project Structure](PROJECT_STRUCTURE.md) - Directory layout and organization
- [Test Framework Guide](TEST_FRAMEWORK.md) - Complete test framework documentation
- [Makefile Reference](MAKEFILE_REFERENCE.md) - All available Make targets and workflows

### Service Documentation
- [Microservices Demo](MICROSERVICES_DEMO.md) - Original Google Cloud microservices demo documentation

### Advanced Topics
- [Go Coverage Guide](GO_COVERAGE_GUIDE.md) - Code-level coverage collection for Go services
- [Tracing and Observability](TRACING_AND_OBSERVABILITY.md) - OpenTelemetry and Jaeger setup
- [Kubernetes Test Deployment](K8S_TEST_DEPLOYMENT.md) - Running tests as Kubernetes Jobs

## Documentation Overview

### Project Structure
Complete directory layout and organization guide including:
- Documentation consolidation rationale
- Script organization by purpose
- Backward compatibility approach
- Migration notes and quick reference

### Test Framework Guide
Comprehensive guide for the BDD test framework including:
- Architecture and project structure
- Writing and running tests
- gRPC client usage
- Health checks and test lifecycle
- Coverage reporting (trace-based and code-level)

### Makefile Reference
Complete reference for all Make targets:
- Complete workflows (`all`, `quick`, `full-ci`)
- Building and deploying services
- Test execution modes (local and K8s)
- Coverage collection and reporting
- Cleanup operations

### Go Coverage Guide
In-depth guide for Go code coverage:
- How Go coverage instrumentation works
- Collecting coverage from running services
- Generating HTML and text reports
- Understanding coverage metrics

### Tracing and Observability
OpenTelemetry and Jaeger setup:
- Deploying the observability stack
- Configuring distributed tracing
- Using Jaeger UI for trace analysis
- Trace-based coverage extraction

### Kubernetes Test Deployment
Running tests in Kubernetes:
- Test runner Job configuration
- RBAC and permissions
- PersistentVolume for reports
- Retrieving test results

## Directory Structure

```
docs/
├── README.md                      # This file
├── PROJECT_STRUCTURE.md           # Directory layout and organization
├── TEST_FRAMEWORK.md              # Main test framework guide
├── MAKEFILE_REFERENCE.md          # Make targets reference
├── GO_COVERAGE_GUIDE.md           # Go coverage documentation
├── TRACING_AND_OBSERVABILITY.md   # OpenTelemetry/Jaeger guide
├── K8S_TEST_DEPLOYMENT.md         # Kubernetes testing guide
└── MICROSERVICES_DEMO.md          # Original demo documentation
```

## Project Structure

```
cisco-demo/
├── README.md                      # Main project README
├── Makefile                       # Main orchestration file
├── docs/                          # All documentation (you are here)
├── scripts/                       # All scripts organized by purpose
│   ├── deployment/                # Kubernetes deployment scripts
│   │   ├── deploy_test_runner.sh
│   │   ├── deploy_tracing_stack.sh
│   │   ├── get_test_reports.sh
│   │   └── *.yaml                 # K8s manifests
│   ├── test-framework/            # Test framework scripts
│   │   ├── entrypoint.sh         # Container entrypoint
│   │   ├── generate_protos.sh    # Proto code generation
│   │   └── run_local_tests.sh    # Local test runner
│   ├── collect-coverage.sh        # Go coverage collection
│   └── port-forward.sh            # Service port-forwarding
├── test-framework/                # BDD test framework
│   ├── config/                    # Service configurations
│   ├── features/                  # Behave test scenarios
│   ├── utils/                     # gRPC clients and utilities
│   ├── generated/                 # Generated protobuf code
│   ├── reports/                   # Test and coverage reports
│   ├── Dockerfile                 # Test container image
│   ├── behave.ini                 # Behave configuration
│   ├── requirements.txt           # Python dependencies
│   └── generate_coverage.py       # Coverage report generator
├── microservices-demo/            # Google Cloud microservices demo
│   ├── src/                       # Service source code
│   └── protos/                    # Protocol buffer definitions
└── makefiles/                     # Modular Makefile components
    ├── cluster.mk                 # Cluster management
    ├── deploy.mk                  # Service deployment
    ├── test.mk                    # Test execution
    ├── coverage.mk                # Coverage collection
    └── ...
```

## Common Workflows

### Quick Start
```bash
# Check if you have all prerequisites
make check-prereqs

# Install prerequisites if not available 
make install-prereqs

# Run the entire workflow, deploy services, deploy tests, collect coverage
make e2e-tests
```

### Test Execution
```bash
# Run tests locally
make test-local

# Run tests in Kubernetes
make test-k8s

# View coverage summary
make coverage-summary
```

### Coverage Collection
```bash
# Collect all coverage (trace + Go)
make coverage

# Generate trace-based coverage only
make generate-trace-coverage

# Collect Go code coverage only
make collect-go-coverage
```

### Cluster Management
```bash
# Create cluster and deploy services
make cluster-create deploy

# Check cluster status
make cluster-status

# Delete cluster
make cluster-delete
```

## Orchestration steps

  This command does the following:
  - Builds custom service images locally
    - Builds Node.js services with OpenTelemetry fixes:
      - currencyservice:local-fixed
      - paymentservice:local-fixed
    - Builds Go services with coverage instrumentation:
      - productcatalogservice:local-coverage
      - checkoutservice:local-coverage
      - shippingservice:local-coverage
  - Creates and verifies Kind cluster
  - Loads images into the cluster
  - Deploys services and observability with Kustomize
  - Starts port-forwarding for local access
  - Runs tests
  - Generates coverage metrics

## Changes made to the source code

Here are some changes made to the source code to support coverage generation and some constraints yet to be addressed:

- Line coverage was only generated from golang services, first attempt was to add instrumentation to all services which failed
- Changes were made to the golang services to use a shared mod that can generate live coverage using a SIGUSR1 command without exiting or restarting the golang servers
- The dockerfiles for golang services were edited to support coverage profiling while the server is running, a total of 3 golang services were edited
- OpenCensus was available on the microservices apart from cart service, OpenTelemetry Collector was added to track system traces and generate behavioural coverage for the overall system. This coverage report shows us total number of API paths and services covered in the stack.
- Changes were made to the node services to fix a bug in trace generation, total 2 services were edited
- Cart Service was restarting duing tests because of low resource allocation, resource allocation was increased in the Kustomize manifests
- OpenTelemetryCollector and Jager were added to the service stack as observability to collect system wide traces and generate behavioural coverage
- Existing unit tests for each services was executed and the coverage reports can be found in the source folder

## Documentation

Comprehensive documentation is available in the [docs/](docs/) directory:

- **[Documentation Index](docs/README.md)** - Complete documentation overview and navigation
- **[Test Framework Guide](docs/TEST_FRAMEWORK.md)** - BDD test framework documentation
- **[Makefile Reference](docs/MAKEFILE_REFERENCE.md)** - All available Make targets
- **[Go Coverage Guide](docs/GO_COVERAGE_GUIDE.md)** - Code-level coverage for Go services
- **[Tracing and Observability](docs/TRACING_AND_OBSERVABILITY.md)** - OpenTelemetry/Jaeger setup
- **[K8s Test Deployment](docs/K8S_TEST_DEPLOYMENT.md)** - Running tests in Kubernetes
- **[Microservices Demo](docs/MICROSERVICES_DEMO.md)** - Original Google Cloud demo docs

## Observability Access

Jaeger UI: ```http://localhost:16686```
Service Endpoints: Various localhost ports (3550, 7070, etc.)

## Further improvements

- Add helm chart deployments and helmfile with test job as helm test hook using helmfile, currently using Kustomize for deployments
- Added unit tests and collected unit tests coverage since not all services has unit tests
- Added contract tests between the consumers and producers in the microservice architecture
- Added UI tests for critical priority happy case user lifecycle flows
- Improved test data management
- Improved line coverage for golang services

## Getting Help

- **Makefile targets**: Run `make help` to see all available targets
- **Test framework**: See [TEST_FRAMEWORK.md](TEST_FRAMEWORK.md)
- **Coverage issues**: See [GO_COVERAGE_GUIDE.md](GO_COVERAGE_GUIDE.md)
- **Tracing setup**: See [TRACING_AND_OBSERVABILITY.md](TRACING_AND_OBSERVABILITY.md)

## Contributing

When adding new documentation:
1. Place all documentation files in the `docs/` directory
2. Update this index with a link to your new document
3. Use clear, descriptive filenames (e.g., `FEATURE_NAME.md`)
4. Follow the existing documentation structure and style
5. Update the main README.md if adding significant new features
