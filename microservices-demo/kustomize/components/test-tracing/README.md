# Test Tracing Component

Kustomize component that adds OpenTelemetry distributed tracing infrastructure for local testing.

## Purpose

This component enables distributed tracing on the microservices-demo application for:
- Test coverage tracking (seeing which services are exercised by tests)
- Debugging service interactions
- Performance analysis
- Trace visualization via Jaeger UI

## What This Component Does

1. **Deploys Observability Infrastructure**:
   - OpenTelemetry Collector (receives traces via OTLP protocol)
   - Jaeger all-in-one (stores and visualizes traces)

2. **Enables Tracing on All Services** (via strategic merge patches):
   - Adds `ENABLE_TRACING=1` environment variable
   - Adds `COLLECTOR_SERVICE_ADDR=opentelemetrycollector:4317` environment variable
   - Applied to: frontend, checkoutservice, productcatalogservice, currencyservice, paymentservice, emailservice, recommendationservice, shippingservice, cartservice, adservice

3. **Fixes Node.js Service Compatibility**:
   - Overrides `currencyservice` image to use `local-fixed` tag
   - Overrides `paymentservice` image to use `local-fixed` tag
   - These images have updated OpenTelemetry SDK dependencies to fix compatibility issues

## Usage

This component is designed to be used with the `test` overlay:

```bash
# Deploy with test overlay (includes this component)
kubectl apply -k ../../overlays/test/
```

Or reference it in your own overlay:

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/test-tracing
```

## Prerequisites

**Before deploying**, ensure the fixed Node.js images are built:

```bash
cd /path/to/project
./build_fixed_node_services.sh
```

This builds:
- `currencyservice:local-fixed` - With `@opentelemetry/sdk-trace-node@1.30.1`
- `paymentservice:local-fixed` - With `@opentelemetry/exporter-trace-otlp-grpc@0.52.1`

## Accessing Jaeger UI

After deployment, set up port-forwarding:

```bash
kubectl port-forward svc/jaeger-query 16686:16686
```

Then access: **http://localhost:16686**

Or use the automated port-forward script:

```bash
cd /path/to/project
./port_forward_services.sh --background
```

## Trace Flow

```
┌─────────────────────┐
│  Microservices      │
│  (OTLP gRPC)        │  ENABLE_TRACING=1
└──────────┬──────────┘  COLLECTOR_SERVICE_ADDR=opentelemetrycollector:4317
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
│  - Stores traces    │
│  - Provides UI      │
└─────────────────────┘
           │ port 16686
           ▼
    ┌──────────────┐
    │  User/Tests  │
    └──────────────┘
```

## Files in This Component

- **kustomization.yaml** - Component definition with patches and image overrides
- **otel-collector.yaml** - OpenTelemetry Collector deployment with health check extension
- **jaeger.yaml** - Jaeger all-in-one deployment (in-memory storage)
- **README.md** - This file

## Node.js Service Fixes

The upstream microservices-demo has OpenTelemetry compatibility issues in Node.js services:

**Problem**: Missing `@opentelemetry/sdk-trace-node` package and outdated exporter
**Error**: `TypeError: provider.addSpanProcessor is not a function`

**Solution**: This component overrides the images with locally-built versions containing:
- `@opentelemetry/sdk-trace-node@1.30.1` (added)
- `@opentelemetry/exporter-trace-otlp-grpc@0.52.1` (updated from 0.26.0)
- Updated import from `@opentelemetry/exporter-otlp-grpc` to `@opentelemetry/exporter-trace-otlp-grpc`

See `build_fixed_node_services.sh` for the build process.

## Why Use a Kustomize Component?

Advantages over direct manifest editing or kubectl patching:
- ✅ **Declarative** - GitOps-friendly configuration
- ✅ **Composable** - Can be combined with other components
- ✅ **Reusable** - Apply to multiple overlays (dev/test/prod)
- ✅ **Clean Upstream Sync** - Base manifests remain unmodified
- ✅ **Single Source of Truth** - All tracing config in one place
- ✅ **Follows Project Convention** - microservices-demo already uses Kustomize components

## Disabling Tracing

To deploy without tracing, use the base manifests directly:

```bash
kubectl apply -k ../../base/
```

Or create an overlay without this component.

## References

- [Kustomize Components Documentation](https://kubectl.docs.kubernetes.io/guides/config_management/components/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Jaeger Tracing](https://www.jaegertracing.io/)
- [Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo)
