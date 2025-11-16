# Observability Stack Deployment

This directory contains reference deployment manifests for the OpenTelemetry Collector and Jaeger observability stack used for test coverage tracking.

**🔄 Deployment Method**: These manifests are now deployed via **Kustomize components** for better composability and clean upstream synchronization.

## Architecture

### Kustomize-Based Deployment

The observability stack uses a layered Kustomize approach:

```
microservices-demo/kustomize/
├── base/                    # Upstream service manifests (unmodified)
├── overlays/test/           # Test environment overlay
│   └── kustomization.yaml   # Combines base + test-tracing component
└── components/test-tracing/ # Observability infrastructure
    ├── kustomization.yaml   # Component definition with patches
    ├── otel-collector.yaml  # OpenTelemetry Collector deployment
    └── jaeger.yaml          # Jaeger all-in-one deployment
```

### How It Works

1. **Base Manifests**: Upstream microservices-demo service definitions (no modifications)
2. **Test Overlay**: References base + adds test-tracing component
3. **Test Tracing Component**: Adds observability via strategic merge patches:
   - Deploys OpenTelemetry Collector and Jaeger
   - Adds `ENABLE_TRACING=1` environment variable to all services
   - Adds `COLLECTOR_SERVICE_ADDR=opentelemetrycollector:4317` to all services
   - Overrides Node.js service images with OTel-fixed versions

## Components

### 1. OpenTelemetry Collector
- **Purpose**: Receives traces from microservices via OTLP protocol
- **Ports**: 4317 (gRPC), 4318 (HTTP), 13133 (health check)
- **Configuration**: Embedded in deployment with health check extension
- **Location**: `../../microservices-demo/kustomize/components/test-tracing/otel-collector.yaml`

### 2. Jaeger
- **Purpose**: Stores and visualizes distributed traces
- **UI Port**: 16686
- **OTLP Port**: 4317 (receives from OTel Collector)
- **Location**: `../../microservices-demo/kustomize/components/test-tracing/jaeger.yaml`

### 3. Service Configuration (via Kustomize Patches)
- **Environment Variables**: Applied to all 10 microservices
  - `ENABLE_TRACING=1` - Enables OpenTelemetry instrumentation
  - `COLLECTOR_SERVICE_ADDR=opentelemetrycollector:4317` - Collector endpoint
- **Image Overrides**: Node.js services use fixed images
  - `currencyservice:local-fixed` - Compatible OTel dependencies
  - `paymentservice:local-fixed` - Compatible OTel dependencies

## Quick Start

### Deploy Everything (Recommended)

The observability stack is automatically deployed with the services:

```bash
cd /path/to/project
./run_all.sh
```

This runs a complete workflow:
1. Creates Kind cluster
2. Builds fixed Node.js images
3. **Deploys services + observability** (single Kustomize command)
4. Sets up port-forwards
5. Runs tests

### Deploy Manually with Kustomize

```bash
# Deploy services with tracing enabled
kubectl apply -k microservices-demo/kustomize/overlays/test/
```

This single command deploys:
- All microservices (from base)
- OpenTelemetry Collector
- Jaeger
- Tracing configuration (environment variables)

### Verify Deployment

Check pods are running:
```bash
kubectl get pods -l app=opentelemetrycollector
kubectl get pods -l app=jaeger
```

Expected output:
```
NAME                                        READY   STATUS    RESTARTS   AGE
opentelemetrycollector-xxxxx-yyyyy         1/1     Running   0          1m
jaeger-xxxxx-yyyyy                         1/1     Running   0          1m
```

### Access Jaeger UI

Set up port-forward:
```bash
kubectl port-forward svc/jaeger-query 16686:16686
```

Or use the automated script (which includes all services + Jaeger):
```bash
cd ../..
./port_forward_services.sh --background
```

Access Jaeger UI:
```
http://localhost:16686
```

## Manual Verification Steps

### 1. Check OpenTelemetry Collector is Receiving Traces

View collector logs:
```bash
kubectl logs -l app=opentelemetrycollector --tail=50 -f
```

You should see logs indicating trace reception:
```
2024-01-15T10:30:45.123Z	info	TracesExporter	{"kind": "exporter", "data_type": "traces", "name": "jaeger", "spans": 12}
```

### 2. Check Jaeger is Receiving Traces

View Jaeger logs:
```bash
kubectl logs -l app=jaeger --tail=50 -f
```

### 3. Generate Test Traces

Run a simple gRPC call to generate traces:
```bash
# Ensure port-forwards are running
./port_forward_services.sh --background

# Make a test call (requires grpcurl)
grpcurl -plaintext localhost:3550 hipstershop.ProductCatalogService/ListProducts
```

Or run the test suite:
```bash
cd test-framework
behave
```

### 4. View Traces in Jaeger UI

1. Open http://localhost:16686
2. Select a service from the dropdown (e.g., "frontend", "productcatalogservice")
3. Click "Find Traces"
4. You should see traces from your test calls

Expected services in Jaeger:
- ✅ frontend
- ✅ checkoutservice
- ✅ productcatalogservice
- ✅ currencyservice
- ✅ paymentservice
- ✅ emailservice
- ✅ recommendationservice
- ⚠️ shippingservice (stub only - limited tracing)
- ❌ cartservice (no tracing instrumentation)
- ❌ adservice (no tracing instrumentation)

## Trace Flow

```
┌─────────────────────┐
│  Microservices      │
│  (OTLP gRPC)        │
└──────────┬──────────┘
           │ port 4317
           ▼
┌─────────────────────┐
│  OTel Collector     │
│  - Receives OTLP    │
│  - Batches spans    │
│  - Adds metadata    │
└──────────┬──────────┘
           │ port 4317 (OTLP)
           ▼
┌─────────────────────┐
│  Jaeger             │
│  - Receives OTLP    │
│  - Stores traces    │
│  - Provides UI      │
└─────────────────────┘
           │ port 16686
           ▼
    ┌──────────────┐
    │  User/Tests  │
    └──────────────┘
```

## Troubleshooting

### No traces appearing in Jaeger

1. **Check if tracing is enabled on services:**
   ```bash
   kubectl get deployment frontend -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ENABLE_TRACING")].value}'
   ```
   Should output: `1`

2. **Check collector is reachable:**
   ```bash
   kubectl get svc opentelemetrycollector
   ```
   Should show ClusterIP service on port 4317

3. **Check collector logs for errors:**
   ```bash
   kubectl logs -l app=opentelemetrycollector --tail=100
   ```

4. **Check Jaeger logs for errors:**
   ```bash
   kubectl logs -l app=jaeger --tail=100
   ```

5. **Verify network connectivity:**
   ```bash
   # From within a pod
   kubectl exec -it <pod-name> -- nc -zv opentelemetrycollector 4317
   ```

### Collector pod won't start

Check events:
```bash
kubectl describe pod -l app=opentelemetrycollector
```

Check for resource issues:
```bash
kubectl top pods
```

### Jaeger pod won't start

Check events:
```bash
kubectl describe pod -l app=jaeger
```

Check for port conflicts:
```bash
kubectl get svc
```

## Configuration Details

### Environment Variables Set on Services

When `deploy_tracing_stack.sh` runs, it adds these environment variables to all microservices:

```yaml
env:
- name: ENABLE_TRACING
  value: "1"
- name: COLLECTOR_SERVICE_ADDR
  value: "opentelemetrycollector:4317"
```

### OTel Collector Configuration

Key settings in `otel-collector-config.yaml`:
- **Receivers**: OTLP gRPC (4317), OTLP HTTP (4318)
- **Processors**: Batch (1s timeout), Memory Limiter (512MB)
- **Exporters**: OTLP to Jaeger (port 4317), Logging (debug)
- **Note**: Uses OTLP exporter instead of deprecated Jaeger exporter

### Jaeger Configuration

Settings in `jaeger-deployment.yaml`:
- **Storage**: In-memory (10,000 traces max)
- **OTLP**: Enabled on collector
- **Ports**: Multiple protocols supported (Jaeger, Zipkin, OTLP)

## Cleanup

To remove the observability stack:

```bash
kubectl delete -f otel-collector-deployment.yaml
kubectl delete -f jaeger-deployment.yaml
```

To disable tracing on services (without removing the stack):

```bash
# Remove ENABLE_TRACING environment variable from all services
for service in frontend checkoutservice productcatalogservice currencyservice paymentservice emailservice recommendationservice shippingservice cartservice adservice; do
    kubectl set env deployment/$service ENABLE_TRACING-
    kubectl set env deployment/$service COLLECTOR_SERVICE_ADDR-
done
```

## Next Steps

Once you've verified traces are being collected:

1. **Run test suite** to generate comprehensive traces
2. **Analyze trace data** to understand service interactions
3. **Build coverage reports** from trace data (future enhancement)
4. **Optimize test scenarios** based on coverage gaps

## Files in this Directory

- **deploy_tracing_stack.sh** - Main deployment script
- **otel-collector-config.yaml** - OTel Collector configuration (reference)
- **otel-collector-deployment.yaml** - K8s manifests for OTel Collector
- **jaeger-deployment.yaml** - K8s manifests for Jaeger
- **enable-tracing-patch.yaml** - Kustomize-style patch file (reference)
- **README.md** - This file

## References

- [OpenTelemetry Collector Docs](https://opentelemetry.io/docs/collector/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OTLP Specification](https://opentelemetry.io/docs/reference/specification/protocol/otlp/)
- [Microservices-Demo Observability](https://github.com/GoogleCloudPlatform/microservices-demo/tree/main/kustomize/components/google-cloud-operations)
