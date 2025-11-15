# Microservices-Demo Test Framework

A comprehensive Python-based BDD (Behavior-Driven Development) test framework for testing the microservices-demo gRPC services using Behave.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Running Tests](#running-tests)
- [Project Structure](#project-structure)
- [Writing New Tests](#writing-new-tests)
- [Troubleshooting](#troubleshooting)
- [Future Enhancements](#future-enhancements)

---

## Overview

This test framework provides:

- **BDD Testing** with Behave for readable, business-friendly test scenarios
- **gRPC Client Wrappers** for all 9 microservices
- **Automated Health Checks** to verify services before testing
- **Modular Design** with separation of concerns
- **Comprehensive Logging** for debugging and traceability
- **JUnit XML Reports** for CI/CD integration

### Tested Services

1. ProductCatalogService
2. CartService
3. RecommendationService
4. CurrencyService
5. CheckoutService
6. PaymentService
7. ShippingService
8. EmailService
9. AdService

---

## Architecture

```
test-framework/
├── config/
│   └── services.yaml          # Service endpoint configuration
├── features/
│   ├── environment.py          # Behave hooks (setup/teardown)
│   ├── product_browsing.feature  # BDD test scenarios
│   └── steps/
│       ├── product_steps.py    # ProductCatalog step definitions
│       ├── cart_steps.py       # Cart step definitions
│       └── recommendation_steps.py  # Recommendation step definitions
├── generated/                  # Generated gRPC Python code (auto-generated)
├── reports/                    # Test reports (JUnit XML)
├── utils/
│   ├── clients/                # gRPC client wrappers
│   │   ├── base_client.py     # Base client class
│   │   ├── product_catalog_client.py
│   │   ├── cart_service_client.py
│   │   ├── recommendation_service_client.py
│   │   ├── currency_service_client.py
│   │   ├── checkout_service_client.py
│   │   ├── payment_service_client.py
│   │   ├── shipping_service_client.py
│   │   ├── email_service_client.py
│   │   └── ad_service_client.py
│   └── config_loader.py        # Configuration management
├── behave.ini                  # Behave configuration
├── generate_protos.sh          # Proto code generation script
├── requirements.txt            # Python dependencies
└── README.md                   # This file
```

---

## Prerequisites

### Required Tools

- **Python 3.8+** - Programming language
  ```bash
  python3 --version  # Should be 3.8 or higher
  ```

- **netcat (nc)** - Network utility for port checking (pre-installed on macOS and most Linux)
  ```bash
  # Verify nc is available
  which nc  # Should show /usr/bin/nc or similar
  ```

- **kubectl** - Kubernetes CLI
  ```bash
  # https://kubernetes.io/docs/tasks/tools/
  kubectl version --client
  ```

- **Kind** - Kubernetes in Docker (for local testing)
  ```bash
  # https://kind.sigs.k8s.io/docs/user/quick-start/#installation
  kind --version
  ```

- **Docker** - Container runtime (required for Kind)
  ```bash
  # https://docs.docker.com/get-docker/
  docker --version
  docker info  # Verify Docker is running
  ```

### Required Services

The microservices-demo application must be deployed and accessible. Services should be port-forwarded to localhost.

Use the provided scripts from the project root:
```bash
# Deploy cluster and set up port-forwards
./run_all.sh

# OR deploy and port-forward separately
./deploy_test_cluster.sh
./port_forward_services.sh
```

---

## Setup

### 1. Install Python Dependencies

```bash
cd test-framework
pip3 install -r requirements.txt
```

**Dependencies installed:**
- `behave` - BDD test framework
- `grpcio` / `grpcio-tools` - gRPC libraries
- `protobuf` - Protocol buffer runtime
- `pyyaml` - Configuration file parsing
- `allure-behave` - Enhanced reporting (optional)

### 2. Generate gRPC Python Code

```bash
./generate_protos.sh
```

**This script:**
- Validates required tools (python3, grpc_tools)
- Uses grpcio-tools bundled protoc compiler (no system protoc required)
- Reads proto files from `../microservices-demo/protos/`
- Generates Python gRPC client code in `generated/`
- Creates proper package structure with `__init__.py` files
- Fixes import paths for cross-platform compatibility

**Output files:**
- `generated/demo_pb2.py` - Proto message classes
- `generated/demo_pb2_grpc.py` - gRPC service stubs
- `generated/grpc/health/v1/health_pb2.py` - Health check messages
- `generated/grpc/health/v1/health_pb2_grpc.py` - Health check stubs

### 3. Verify Configuration

Check `config/services.yaml` to ensure service endpoints match your environment:

```yaml
services:
  productcatalog:
    host: localhost
    port: 3550
  cart:
    host: localhost
    port: 7070
  # ... other services
```

**Note:** Default configuration assumes services are port-forwarded to localhost. Modify if using different endpoints.

---

## Running Tests

### Option 1: Full Automated Workflow (Recommended)

From the project root:

```bash
./run_all.sh
```

**This script:**
1. Deploys microservices to Kind cluster
2. Sets up port-forwards in background
3. Installs test dependencies (if needed)
4. Generates proto code (if needed)
5. Runs all tests with Behave
6. Cleans up resources
7. Asks if you want to keep port-forwards running

### Option 2: Manual Test Execution

**Step 1: Deploy Services**

```bash
# From project root
./deploy_test_cluster.sh
```

**Step 2: Set Up Port-Forwards**

```bash
# Run in background (for automation)
./port_forward_services.sh --background

# OR run in foreground (keeps terminal open, Ctrl+C to stop)
./port_forward_services.sh
```

**Step 3: Run Tests**

```bash
cd test-framework

# Run all tests
behave

# Run with verbose output
behave -v

# Run specific feature
behave features/product_browsing.feature

# Run with specific tags (when tags are added to scenarios)
behave --tags=@smoke

# Generate JUnit XML report
behave --junit --junit-directory reports/
```

### Option 3: Run Individual Scenarios

```bash
cd test-framework

# Run specific scenario by line number
behave features/product_browsing.feature:5

# Run with dry-run to see steps without executing
behave --dry-run

# Stop on first failure
behave --stop
```

---

## Project Structure

### Configuration

**config/services.yaml**
- Service endpoint mappings (host:port)
- Test configuration (timeouts, retries)
- Kubernetes settings (context, namespace)

### Features

**features/product_browsing.feature**
- Gherkin-syntax test scenarios
- Human-readable business requirements
- Scenario: Browse products and add to cart

**features/environment.py**
- `before_all()`: Initialize gRPC clients, perform health checks
- `before_scenario()`: Generate unique test user ID, initialize state
- `after_scenario()`: Clean up test data (empty cart)
- `after_all()`: Close gRPC connections

**Health Check Strategy:**
- All services are health-checked in `before_all()` hook
- Tests fail fast if any service is unhealthy
- Reduces test flakiness
- Provides clear error messages

### Step Definitions

**features/steps/product_steps.py**
- List all products
- Get product details
- Verify product information

**features/steps/cart_steps.py**
- Add items to cart
- Retrieve cart contents
- Verify cart state (item count, quantities)

**features/steps/recommendation_steps.py**
- Request product recommendations
- Verify recommendations received

### gRPC Clients

**utils/clients/**
- Each service has its own client class
- All inherit from `BaseGrpcClient`
- Provide typed, documented methods
- Handle connection management
- Include health check support via gRPC Health Check Protocol

**Client Classes:**
1. `ProductCatalogClient` - List/get/search products
2. `CartServiceClient` - Add/get/empty cart
3. `RecommendationServiceClient` - Get recommendations
4. `CurrencyServiceClient` - Get currencies, convert
5. `CheckoutServiceClient` - Place orders
6. `PaymentServiceClient` - Process payments
7. `ShippingServiceClient` - Get quotes, ship orders
8. `EmailServiceClient` - Send confirmations
9. `AdServiceClient` - Get advertisements

---

## Writing New Tests

### 1. Create a New Feature File

Create `features/currency_conversion.feature`:

```gherkin
Feature: Currency Conversion
  As a customer
  I want to see prices in my currency
  So that I can understand costs

  Scenario: Convert USD to EUR
    When I get supported currencies
    Then I should see "EUR" in the list
    When I convert 100 USD to EUR
    Then I should receive a valid EUR amount
```

### 2. Create Step Definitions

Create `features/steps/currency_steps.py`:

```python
from behave import when, then
import logging
from generated import demo_pb2

logger = logging.getLogger(__name__)

@when('I get supported currencies')
def step_get_currencies(context):
    response = context.currency_client.get_supported_currencies()
    context.currencies = response.currency_codes
    logger.info(f"Received {len(context.currencies)} currencies")

@then('I should see "{currency}" in the list')
def step_verify_currency_in_list(context, currency):
    assert currency in context.currencies, \
        f"{currency} not found in supported currencies"
    logger.info(f"✓ {currency} is supported")

@when('I convert {amount:d} USD to EUR')
def step_convert_currency(context, amount):
    money = demo_pb2.Money(currency_code="USD", units=amount, nanos=0)
    response = context.currency_client.convert(money, "EUR")
    context.converted_amount = response
    logger.info(f"Converted {amount} USD to EUR")

@then('I should receive a valid EUR amount')
def step_verify_conversion(context):
    assert context.converted_amount.currency_code == "EUR"
    assert context.converted_amount.units > 0
    logger.info(f"✓ Received valid EUR amount: {context.converted_amount.units}")
```

### 3. Update environment.py (if needed)

If clients are already initialized in `before_all()`, no changes needed. The `currency_client` is already available.

### 4. Run Your New Tests

```bash
behave features/currency_conversion.feature -v
```

---

## Test Reports

### JUnit XML Reports

Generated in `reports/` directory:

```bash
behave --junit --junit-directory reports/
```

**Use these reports for:**
- CI/CD integration (Jenkins, GitLab CI, GitHub Actions)
- Test result tracking over time
- Historical analysis and trends

### Console Output

Behave provides colored, formatted output:
- **Green**: Passed steps ✓
- **Red**: Failed steps ✗
- **Yellow**: Skipped/undefined steps ⊘
- **Cyan**: Scenario names and descriptions

**Example output:**
```
Feature: Product Browsing and Cart Management

  Scenario: Browse products and add item to cart
    When I list all available products ... passed in 0.142s
    Then I should receive a non-empty product list ... passed in 0.001s
    When I get details for the first product ... passed in 0.089s
    ...
```

---

## Troubleshooting

### Problem: "grpc_tools not found"

**Solution:**
```bash
pip3 install -r requirements.txt
```

**Note:** System `protoc` is NOT required. The `grpcio-tools` package includes a bundled protoc compiler that's compatible with the generated Python code.

### Problem: "Service health check failed"

**Symptoms:**
```
RuntimeError: Service health check failed for: Product Catalog, Cart Service
```

**Solution:**
1. Verify cluster is running:
   ```bash
   kubectl cluster-info --context kind-microservices-demo
   ```

2. Check deployments are ready:
   ```bash
   kubectl get deployments
   kubectl get pods
   ```

3. Ensure port-forwards are active:
   ```bash
   ./port_forward_services.sh --background

   # Verify port-forwards are running
   ps aux | grep "kubectl port-forward"
   ```

4. Test connectivity manually:
   ```bash
   nc -zv localhost 3550  # Product catalog
   nc -zv localhost 7070  # Cart service
   ```

### Problem: "grpc_tools not found"

**Solution:**
```bash
pip3 install -r requirements.txt
```

### Problem: "Generated proto files not found"

**Symptoms:**
```
ImportError: cannot import name 'demo_pb2' from 'generated'
```

**Solution:**
```bash
./generate_protos.sh
```

### Problem: "Connection refused" errors

**Symptoms:**
```
grpc.RpcError: <_InactiveRpcError ... UNAVAILABLE: failed to connect to all addresses>
```

**Solution:**
1. Check port-forwards are running:
   ```bash
   ps aux | grep "kubectl port-forward"
   ```

2. Restart port-forwards:
   ```bash
   # Stop existing
   kill $(cat /tmp/microservices-port-forwards.pids)

   # Restart
   ./port_forward_services.sh --background
   ```

3. Verify services are healthy in cluster:
   ```bash
   kubectl get pods
   kubectl logs <pod-name>
   ```

### Problem: Tests fail with "Cart contains unexpected items"

**Cause:** Cart not cleaned up from previous failed test.

**Solution:**
- Each test uses a unique user ID (timestamp-based) to avoid conflicts
- Cart cleanup happens in `after_scenario()` hook
- If tests fail before cleanup, carts may persist in Redis
- Manual cleanup: Restart cart service or Redis
  ```bash
  kubectl rollout restart deployment/cartservice
  kubectl rollout restart deployment/redis-cart
  ```

### Debug Mode

Enable debug logging in `behave.ini`:

```ini
[behave]
logging_level = DEBUG
```

Or run with verbose flag and capture output:

```bash
behave -v --no-capture --no-capture-stderr
```

View detailed gRPC traces:

```bash
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all
behave -v
```

---

## Future Enhancements

### Additional Test Scenarios

1. **Complete Checkout Flow**
   - Place order end-to-end
   - Test payment processing
   - Verify shipping cost calculation
   - Validate email notifications

2. **Error Handling**
   - Invalid product IDs
   - Empty cart checkout
   - Invalid currency codes
   - Network failures and retries

3. **Load Testing**
   - Concurrent cart operations
   - High-volume product queries
   - Stress test recommendations
   - Service degradation scenarios

4. **Integration Tests**
   - Multi-service workflows
   - Data consistency across services
   - Transaction rollback scenarios
   - Service mesh behavior

### Framework Improvements

1. **Test Data Management**
   - Fixtures for common test data
   - Data builders for complex proto objects
   - Test data cleanup strategies
   - Shared test state management

2. **Parallel Execution**
   - Run scenarios in parallel: `behave --processes 4`
   - Isolated test users per process
   - Thread-safe client connections
   - Parallel-safe cleanup

3. **Coverage Reporting**
   - Service call coverage matrix
   - Scenario coverage by service
   - API endpoint coverage
   - Proto field coverage

4. **CI/CD Integration**
   - GitHub Actions workflow
   - Automated test execution on PR
   - Test result publishing
   - Performance regression detection

5. **Performance Testing**
   - Response time assertions
   - Latency percentiles (p50, p95, p99)
   - Service SLO validation
   - Resource usage monitoring

6. **Test Tags**
   - `@smoke` - Quick smoke tests
   - `@regression` - Full regression suite
   - `@slow` - Long-running tests
   - `@service:cart` - Service-specific tests

---

## Contributing

### Adding New Services

If new services are added to microservices-demo:

1. Create client in `utils/clients/my_service_client.py`
2. Extend `BaseGrpcClient`
3. Import in `utils/clients/__init__.py`
4. Initialize in `features/environment.py`
5. Add health check to `before_all()`
6. Write test scenarios

### Code Style

- Follow **PEP 8** style guide
- Use **type hints** where applicable
- Document all public methods with docstrings
- Add **logging** for debugging (INFO level minimum)
- Keep functions small and focused (Single Responsibility)

### Testing Best Practices

- **Keep scenarios focused and independent** - Each scenario should test one thing
- **Use descriptive step names** - Steps should read like plain English
- **Avoid hard-coded test data** - Use parameterized steps
- **Clean up resources** - Always cleanup in `after_scenario()`
- **Use unique user IDs** - Prevent test interference (already implemented)
- **Fail fast** - Health checks prevent wasted test runs

---

## Resources

- [Behave Documentation](https://behave.readthedocs.io/)
- [gRPC Python Guide](https://grpc.io/docs/languages/python/)
- [Microservices-Demo GitHub](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Protocol Buffers Guide](https://developers.google.com/protocol-buffers)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Testing Best Practices](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## License

This test framework follows the same license as the microservices-demo project (Apache License 2.0).

---

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Behave and gRPC documentation
3. Examine logs in verbose mode (`behave -v`)
4. Check service health and connectivity
5. Verify proto files are up to date
6. Regenerate proto code if needed

---

## Observability and Test Coverage

### Distributed Tracing with OpenTelemetry and Jaeger

The test framework supports distributed tracing to track service interactions and generate coverage reports.

**What You Get:**
- Visual traces of requests flowing through microservices
- Identification of which services and gRPC methods were called during tests
- Performance metrics (latency, timing)
- Call graphs showing service dependencies

### Quick Start: Enable Tracing

**1. Deploy the observability stack:**
```bash
cd deploy_scripts
./deploy_tracing_stack.sh
```

This deploys:
- OpenTelemetry Collector (receives traces from services)
- Jaeger (stores and visualizes traces)
- Enables tracing on all microservices

**2. Set up port-forwards (including Jaeger UI):**
```bash
cd ..
./port_forward_services.sh --background
```

**3. Run tests to generate traces:**
```bash
cd test-framework
behave
```

**4. View traces in Jaeger UI:**
```
http://localhost:16686
```

### Trace Coverage

**Services with Full Tracing:**
- ✅ frontend (Go)
- ✅ checkoutservice (Go)
- ✅ productcatalogservice (Go)
- ✅ currencyservice (Node.js)
- ✅ paymentservice (Node.js)
- ✅ emailservice (Python)
- ✅ recommendationservice (Python)

**Services with Limited/No Tracing:**
- ⚠️ shippingservice (Go - stub only)
- ❌ cartservice (C# - no instrumentation)
- ❌ adservice (Java - no instrumentation)

**Note:** Calls TO services without tracing will still appear in traces from calling services.

### Using Jaeger UI

1. **Select a service** from the dropdown (e.g., "productcatalogservice")
2. **Click "Find Traces"** to see recent traces
3. **Click on a trace** to see the detailed span view
4. **Analyze the timeline** to see request flow and timing

**Useful Jaeger Features:**
- Filter by operation (gRPC method name)
- Search by tags (service.name, http.method, etc.)
- Compare traces to identify performance regressions
- Export traces for further analysis

### Trace-Based Coverage (Future)

In future enhancements, the framework will automatically:
- Extract service and method coverage from traces
- Generate HTML coverage reports
- Track coverage improvements across test runs
- Identify untested workflows

See [deploy_scripts/README.md](deploy_scripts/README.md) for detailed observability setup documentation.

---

**Happy Testing!** 🧪✨
