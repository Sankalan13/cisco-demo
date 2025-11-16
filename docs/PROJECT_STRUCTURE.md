# Project Structure

This document describes the organization of the cisco-demo testing framework project.

## Overview

The project has been reorganized for better clarity and maintainability:
- **All documentation** is in the `docs/` directory
- **All scripts** are in the `scripts/` directory with logical subdirectories
- **Backward compatibility** is maintained through Makefile abstractions

## Directory Layout

```
cisco-demo/
├── README.md                          # Main project overview
├── Makefile                           # Main orchestration (use 'make help')
│
├── docs/                              # All documentation
│   ├── README.md                      # Documentation index
│   ├── TEST_FRAMEWORK.md              # Test framework guide
│   ├── MAKEFILE_REFERENCE.md          # Make targets reference
│   ├── GO_COVERAGE_GUIDE.md           # Go coverage documentation
│   ├── TRACING_AND_OBSERVABILITY.md   # OpenTelemetry/Jaeger guide
│   ├── K8S_TEST_DEPLOYMENT.md         # Kubernetes testing guide
│   ├── MICROSERVICES_DEMO.md          # Original demo documentation
│   └── PROJECT_STRUCTURE.md           # This file
│
├── scripts/                           # All executable scripts
│   ├── deployment/                    # Kubernetes deployment scripts
│   │   ├── deploy_test_runner.sh      # Deploy test Job to K8s
│   │   ├── deploy_tracing_stack.sh    # Deploy OpenTelemetry/Jaeger
│   │   ├── get_test_reports.sh        # Retrieve reports from K8s PVC
│   │   ├── test-runner-job.yaml       # Test runner Job manifest
│   │   ├── test-runner-rbac.yaml      # RBAC for test runner
│   │   ├── test-reports-pvc.yaml      # PVC for test reports
│   │   ├── jaeger-deployment.yaml     # Jaeger configuration
│   │   ├── otel-collector-*.yaml      # OpenTelemetry Collector
│   │   └── enable-tracing-patch.yaml  # Tracing enablement patch
│   │
│   ├── test-framework/                # Test framework scripts
│   │   ├── entrypoint.sh              # Container entrypoint (K8s mode)
│   │   ├── generate_protos.sh         # Proto code generation
│   │   └── run_local_tests.sh         # Local test runner
│   │
│   ├── collect-coverage.sh            # Go coverage collection
│   └── port-forward.sh                # Service port-forwarding
│
├── test-framework/                    # BDD test framework
│   ├── config/                        # Configuration files
│   │   ├── services.yaml              # Local mode endpoints
│   │   └── services-k8s.yaml          # Kubernetes mode endpoints
│   │
│   ├── features/                      # Behave BDD tests
│   │   ├── environment.py             # Test lifecycle hooks
│   │   ├── *.feature                  # Gherkin test scenarios
│   │   └── steps/                     # Step definitions
│   │       └── *_steps.py
│   │
│   ├── utils/                         # Utilities and clients
│   │   ├── clients/                   # gRPC client wrappers
│   │   │   ├── base_client.py
│   │   │   └── *_client.py
│   │   └── config_loader.py
│   │
│   ├── generated/                     # Generated protobuf code
│   │   ├── demo_pb2.py
│   │   ├── demo_pb2_grpc.py
│   │   └── grpc/health/v1/
│   │
│   ├── reports/                       # Test and coverage reports
│   │   ├── *.xml                      # JUnit XML reports
│   │   ├── behave_output.txt          # Behave summary
│   │   ├── coverage.json              # Trace-based coverage
│   │   ├── go-coverage-*.html         # Go coverage reports
│   │   ├── go-coverage-summary.txt    # Go coverage summary
│   │   └── go-coverage/               # Raw coverage data
│   │
│   ├── Dockerfile                     # Test container image
│   ├── behave.ini                     # Behave configuration
│   ├── requirements.txt               # Python dependencies
│   └── generate_coverage.py           # Coverage report generator
│
├── microservices-demo/                # Google Cloud demo (modified)
│   ├── src/                           # Service source code
│   │   ├── *service/                  # Individual services
│   │   └── shared/                    # Shared Go modules
│   ├── protos/                        # Protocol buffer definitions
│   │   ├── demo.proto
│   │   └── grpc/health/v1/health.proto
│   └── kustomize/                     # Kustomize configurations
│       ├── base/
│       └── components/
│           └── test-tracing/          # Tracing overlay
│
├── makefiles/                         # Modular Makefile components
│   ├── docker.mk                      # Docker image building
│   ├── cluster.mk                     # Cluster management
│   ├── deploy.mk                      # Service deployment
│   ├── test.mk                        # Test execution
│   ├── coverage.mk                    # Coverage collection
│   ├── proto.mk                       # Proto generation
│   └── port-forward.mk                # Port forwarding
│
└── .build/                            # Sentinel files (cache invalidation)
    ├── cluster-created
    ├── images-built
    ├── deployed
    └── *                              # Other build markers
```

## Key Design Decisions

### 1. Documentation Consolidation

**Why**: Single source of truth for all documentation

**Before**:
```
├── README.md
├── test-framework/README.md
├── microservices-demo/README.md
└── test-framework/deploy_scripts/README*.md
```

**After**:
```
docs/
├── README.md                        # Index
├── TEST_FRAMEWORK.md                # Moved from test-framework/
├── MICROSERVICES_DEMO.md            # Moved from microservices-demo/
├── TRACING_AND_OBSERVABILITY.md     # Moved from deploy_scripts/
└── K8S_TEST_DEPLOYMENT.md           # Moved from deploy_scripts/
```

### 2. Script Organization

**Why**: Logical grouping by purpose, easier to find and maintain

**Before**:
```
├── test-framework/generate_protos.sh
├── test-framework/run_local_tests.sh
├── test-framework/entrypoint.sh
├── test-framework/deploy_scripts/*.sh
├── collect_go_coverage.sh
└── port_forward_services.sh
```

**After**:
```
scripts/
├── deployment/          # All K8s deployment scripts
│   ├── deploy_*.sh
│   ├── get_*.sh
│   └── *.yaml
├── test-framework/      # Test execution scripts
│   ├── entrypoint.sh
│   ├── generate_protos.sh
│   └── run_local_tests.sh
├── collect-coverage.sh  # Coverage collection
└── port-forward.sh      # Port forwarding
```

### 3. Backward Compatibility

**How**: Makefiles abstract script locations

Users don't need to know where scripts are located:
```bash
# Still works the same way
make all
make test
make coverage
make full-ci
```

The Makefile handles the new paths internally:
```makefile
SCRIPTS_DIR := scripts
DEPLOY_SCRIPTS_DIR := $(SCRIPTS_DIR)/deployment
```

## Migration Notes

### For Users

**No changes required!** Continue using `make` commands as before:

```bash
make all          # Full workflow
make quick        # Fast iteration
make test         # Run tests
make coverage     # Generate coverage
make full-ci      # Full CI workflow
```

### For Developers

**Script references updated**:

| Old Path | New Path |
|----------|----------|
| `test-framework/generate_protos.sh` | `scripts/test-framework/generate_protos.sh` |
| `test-framework/run_local_tests.sh` | `scripts/test-framework/run_local_tests.sh` |
| `test-framework/entrypoint.sh` | `scripts/test-framework/entrypoint.sh` |
| `test-framework/deploy_scripts/*.sh` | `scripts/deployment/*.sh` |
| `collect_go_coverage.sh` | `scripts/collect-coverage.sh` |
| `port_forward_services.sh` | `scripts/port-forward.sh` |

**Documentation references updated**:

| Old Path | New Path |
|----------|----------|
| `test-framework/README.md` | `docs/TEST_FRAMEWORK.md` |
| `microservices-demo/README.md` | `docs/MICROSERVICES_DEMO.md` |
| `test-framework/deploy_scripts/README.md` | `docs/TRACING_AND_OBSERVABILITY.md` |
| `test-framework/deploy_scripts/README-k8s-deployment.md` | `docs/K8S_TEST_DEPLOYMENT.md` |

## File References

### Files Updated

All references to moved files have been updated in:

1. **Makefiles**:
   - `Makefile` - Main orchestration
   - `makefiles/test.mk` - Test execution
   - `makefiles/coverage.mk` - Coverage collection

2. **Docker Images**:
   - `test-framework/Dockerfile` - Updated entrypoint path

3. **Scripts**:
   - `scripts/test-framework/generate_protos.sh` - Updated paths

4. **Documentation**:
   - `README.md` - Added documentation index
   - `docs/GO_COVERAGE_GUIDE.md` - Updated script references
   - `docs/K8S_TEST_DEPLOYMENT.md` - Updated script references

## Benefits

### 1. Clarity
- Clear separation: docs vs. scripts vs. source code
- Easy to find what you need
- Logical grouping by purpose

### 2. Maintainability
- Single location for all documentation
- Scripts organized by function
- Easier onboarding for new contributors

### 3. Scalability
- Easy to add new docs (just drop in `docs/`)
- Easy to add new scripts (choose appropriate subdirectory)
- No confusion about where things belong

### 4. Backward Compatibility
- Existing workflows unchanged
- No disruption to users
- Makefile abstracts implementation details

## Quick Reference

### Running Tests

```bash
# Local mode (recommended for development)
make test-local

# Kubernetes mode (recommended for CI)
make test-k8s
# or
make full-ci
```

### Accessing Scripts Directly

If needed, scripts can be run directly:

```bash
# Generate proto code
scripts/test-framework/generate_protos.sh

# Run local tests
scripts/test-framework/run_local_tests.sh

# Collect coverage
scripts/collect-coverage.sh

# Deploy to Kubernetes
scripts/deployment/deploy_test_runner.sh

# Retrieve K8s reports
scripts/deployment/get_test_reports.sh
```

### Documentation

All documentation is in [`docs/`](../docs/):

```bash
# View documentation index
cat docs/README.md

# Read specific guides
less docs/TEST_FRAMEWORK.md
less docs/GO_COVERAGE_GUIDE.md
```

## See Also

- [Documentation Index](README.md) - All available documentation
- [Makefile Reference](MAKEFILE_REFERENCE.md) - Complete Make targets reference
- [Test Framework Guide](TEST_FRAMEWORK.md) - BDD testing documentation
