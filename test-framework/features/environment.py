"""Behave environment hooks for test setup and teardown."""

import sys
import time
import json
import logging
from pathlib import Path
from datetime import datetime, timezone
from behave import register_type
import parse

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Register custom parse types for step parameters
@parse.with_pattern(r'\d+\.?\d*')
def parse_float(text):
    """Parse float values for step parameters."""
    return float(text)

register_type(f=parse_float)

from utils.clients import (
    ProductCatalogClient,
    CartServiceClient,
    RecommendationServiceClient,
    CurrencyServiceClient,
    CheckoutServiceClient,
    PaymentServiceClient,
    ShippingServiceClient,
    EmailServiceClient,
    AdServiceClient,
)

# OpenTelemetry imports
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.grpc import GrpcInstrumentorClient

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global tracer instance
tracer = None


def init_tracing():
    """Initialize OpenTelemetry tracing for test client instrumentation.

    This sets up:
    - TracerProvider with test framework identification
    - OTLP exporter to send traces to OpenTelemetry Collector
    - Automatic gRPC client instrumentation
    """
    global tracer

    # Import config to get OTel Collector endpoint
    from utils.config_loader import get_config
    config = get_config()

    # Get OTel Collector endpoint from config
    # Default to localhost:4317 if not specified
    try:
        observability_config = config._config.get('observability', {})
        otel_config = observability_config.get('otel_collector', {})
        otel_host = otel_config.get('host', 'localhost')
        otel_port = otel_config.get('port', 4317)
        otel_endpoint = f"{otel_host}:{otel_port}"
    except Exception:
        # Fallback to default
        otel_endpoint = "localhost:4317"

    logger.info(f"Initializing OpenTelemetry tracing...")
    logger.info(f"  OTel Collector endpoint: {otel_endpoint}")

    # Create resource identifying this as the test framework
    resource = Resource.create({
        "service.name": "test-framework",
        "service.version": "1.0.0",
    })

    # Create TracerProvider
    provider = TracerProvider(resource=resource)

    # Create OTLP exporter
    otlp_exporter = OTLPSpanExporter(
        endpoint=otel_endpoint,
        insecure=True,  # No TLS for local testing
    )

    # Add span processor
    span_processor = BatchSpanProcessor(otlp_exporter)
    provider.add_span_processor(span_processor)

    # Set as global provider
    trace.set_tracer_provider(provider)

    # Get tracer instance
    tracer = trace.get_tracer(__name__)

    # Instrument gRPC clients automatically
    # This adds trace context propagation to all gRPC channels
    GrpcInstrumentorClient().instrument()

    logger.info("✓ OpenTelemetry tracing initialized")
    logger.info("✓ gRPC clients instrumented for distributed tracing")

    return tracer


def before_all(context):
    """Set up test environment before all tests.

    This hook:
    - Initializes OpenTelemetry distributed tracing
    - Records test execution start time for coverage generation
    - Initializes all gRPC clients
    - Performs health checks on all services
    - Fails fast if services are not healthy
    """
    global tracer

    # Initialize OpenTelemetry tracing first
    # This must happen before creating gRPC clients
    try:
        tracer = init_tracing()
        context.tracer = tracer
    except Exception as e:
        logger.warning(f"Failed to initialize OpenTelemetry tracing: {e}")
        logger.warning("Tests will run without distributed tracing")
        context.tracer = None

    # Record test execution start time for coverage generation
    # Add a buffer before actual test start to capture trace propagation
    logger.info("="*60)
    logger.info("Setting up test environment...")
    logger.info("="*60)
    logger.info("Waiting 3 seconds before recording start time (trace buffer)...")
    time.sleep(3)
    context.test_start_time = datetime.now(timezone.utc)
    logger.info(f"Test start time recorded: {context.test_start_time.isoformat()}")

    # Initialize gRPC clients
    logger.info("Initializing gRPC clients...")
    context.product_catalog_client = ProductCatalogClient()
    context.cart_client = CartServiceClient()
    context.recommendation_client = RecommendationServiceClient()
    context.currency_client = CurrencyServiceClient()
    context.checkout_client = CheckoutServiceClient()
    context.payment_client = PaymentServiceClient()
    context.shipping_client = ShippingServiceClient()
    context.email_client = EmailServiceClient()
    context.ad_client = AdServiceClient()

    logger.info("All gRPC clients initialized")

    # Perform health checks with retry logic
    logger.info("")
    logger.info("Performing service health checks with retry logic...")
    logger.info("-" * 60)

    services_to_check = [
        ('Product Catalog', context.product_catalog_client),
        ('Cart Service', context.cart_client),
        ('Recommendation Service', context.recommendation_client),
        ('Currency Service', context.currency_client),
        ('Checkout Service', context.checkout_client),
        ('Payment Service', context.payment_client),
        ('Shipping Service', context.shipping_client),
        ('Email Service', context.email_client),
        ('Ad Service', context.ad_client),
    ]

    # Health check configuration
    MAX_RETRIES = 10
    RETRY_DELAY = 2  # seconds

    # Retry loop for health checks
    all_healthy = False
    for attempt in range(1, MAX_RETRIES + 1):
        logger.info(f"Health check attempt {attempt}/{MAX_RETRIES}")

        failed_services = []
        for service_name, client in services_to_check:
            try:
                is_healthy = client.check_health()
                if is_healthy:
                    logger.info(f"✓ {service_name}: HEALTHY")
                else:
                    logger.warning(f"⚠ {service_name}: UNHEALTHY")
                    failed_services.append(service_name)
            except Exception as e:
                logger.warning(f"⚠ {service_name}: {str(e)}")
                failed_services.append(service_name)

        # Check if all services are healthy
        if not failed_services:
            all_healthy = True
            logger.info("-" * 60)
            logger.info("")
            logger.info("✓ All services are healthy!")
            logger.info("="*60)
            logger.info("")
            break

        # If not all healthy and more retries available
        if attempt < MAX_RETRIES:
            logger.warning(f"{len(failed_services)} service(s) not ready: {', '.join(failed_services)}")
            logger.info(f"Retrying in {RETRY_DELAY} seconds...")
            logger.info("")
            time.sleep(RETRY_DELAY)
        else:
            # Final attempt failed
            logger.error("-" * 60)
            logger.error("")
            logger.error(f"Health check failed after {MAX_RETRIES} attempts")
            logger.error("The following services are not healthy:")
            for service in failed_services:
                logger.error(f"  - {service}")
            logger.error("")
            logger.error("Troubleshooting steps:")
            logger.error("  1. Verify cluster is running: kubectl get pods")
            logger.error("  2. Check port-forwards: ps aux | grep 'kubectl port-forward'")
            logger.error("  3. Restart port-forwards: ./port_forward_services.sh --background")
            logger.error("  4. Check service logs: kubectl logs <pod-name>")
            raise RuntimeError(f"Service health check failed for: {', '.join(failed_services)}")


def before_scenario(context, scenario):
    """Set up before each scenario.

    This hook:
    - Creates a root span for the test scenario (for distributed tracing)
    - Generates a unique test user ID
    - Logs scenario start
    """
    # Generate unique user ID for this test scenario
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    context.user_id = f"test-user-{timestamp}"

    logger.info("")
    logger.info("="*60)
    logger.info(f"Starting scenario: {scenario.name}")
    logger.info(f"Test user ID: {context.user_id}")
    logger.info("="*60)

    # Create root span for this test scenario
    # This span will be the parent for all gRPC calls made during the test
    if hasattr(context, 'tracer') and context.tracer is not None:
        scenario_span = context.tracer.start_span(
            name=f"test.scenario.{scenario.name}",
            attributes={
                "test.user_id": context.user_id,
                "test.feature": scenario.feature.name,
                "test.scenario": scenario.name,
            }
        )
        context.scenario_span = scenario_span
        context.scenario_span_context = trace.set_span_in_context(scenario_span)
        logger.info(f"✓ Created root span for scenario: {scenario.name}")
    else:
        context.scenario_span = None
        context.scenario_span_context = None

    # Initialize scenario-specific state
    context.products = None
    context.current_product = None
    context.cart = None
    context.recommendations = None


def after_scenario(context, scenario):
    """Clean up after each scenario.

    This hook:
    - Ends the root span for distributed tracing
    - Empties the test user's cart
    - Logs scenario result
    """
    logger.info("")
    logger.info("-"*60)
    logger.info(f"Scenario: {scenario.name}")
    logger.info(f"Status: {'PASSED' if scenario.status == 'passed' else 'FAILED'}")

    # Clean up: empty the test user's cart
    try:
        if hasattr(context, 'user_id') and context.user_id:
            logger.info(f"Cleaning up cart for user: {context.user_id}")
            context.cart_client.empty_cart(context.user_id)
            logger.info("Cart cleaned up successfully")
    except Exception as e:
        logger.warning(f"Failed to clean up cart: {str(e)}")

    # End the root span for this scenario
    if hasattr(context, 'scenario_span') and context.scenario_span is not None:
        # Set span status based on scenario result
        if scenario.status == 'passed':
            context.scenario_span.set_status(trace.Status(trace.StatusCode.OK))
        else:
            context.scenario_span.set_status(
                trace.Status(trace.StatusCode.ERROR, f"Scenario failed: {scenario.status}")
            )
        context.scenario_span.end()
        logger.info(f"✓ Ended root span for scenario: {scenario.name}")

    logger.info("-"*60)
    logger.info("")


def after_all(context):
    """Clean up after all tests.

    This hook:
    - Records test execution end time for coverage generation
    - Writes test execution time window to file for coverage script
    - Closes all gRPC client connections
    """
    logger.info("")
    logger.info("="*60)
    logger.info("Cleaning up test environment...")
    logger.info("="*60)

    # Flush OpenTelemetry spans before recording end time
    # This ensures all spans are exported to the collector before tests end
    logger.info("Flushing OpenTelemetry spans...")
    try:
        # Get the tracer provider and force flush all spans
        from opentelemetry import trace as otel_trace
        tracer_provider = otel_trace.get_tracer_provider()

        # Force flush with timeout (give it up to 10 seconds to export all spans)
        if hasattr(tracer_provider, 'force_flush'):
            flush_success = tracer_provider.force_flush(timeout_millis=10000)
            if flush_success:
                logger.info("✓ All spans flushed successfully")
            else:
                logger.warning("⚠ Span flush timed out (some spans may not be exported)")
        else:
            logger.warning("TracerProvider does not support force_flush")

        # Add delay to ensure spans reach Jaeger and are indexed
        logger.info("Waiting 5 seconds for spans to reach Jaeger and be indexed...")
        time.sleep(5)
        logger.info("✓ Span export complete")

    except Exception as e:
        logger.warning(f"Error flushing OpenTelemetry spans: {e}")
        logger.warning("Some spans may not be exported to Jaeger")

    # Record test execution end time AFTER spans are flushed
    # Add a buffer to ensure all traces are indexed in Jaeger
    context.test_end_time = datetime.now(timezone.utc)
    logger.info(f"Test end time recorded: {context.test_end_time.isoformat()}")

    # Write test execution time window to file for coverage generation
    # This allows run_all.sh to know the exact time range to query
    # Only write if test_start_time exists (before_all may have failed)
    if hasattr(context, 'test_start_time') and hasattr(context, 'test_end_time'):
        test_time_file = project_root / "reports" / "test_execution_time.json"
        test_time_file.parent.mkdir(parents=True, exist_ok=True)

        try:
            # Format datetimes with UTC timezone indicator
            def format_datetime(dt):
                """Format datetime with UTC timezone indicator."""
                if dt is None:
                    return None
                # Ensure timezone-aware (should already be UTC)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
                # Use ISO format with 'Z' suffix for UTC
                return dt.isoformat().replace('+00:00', 'Z')

            test_time_data = {
                "start_time": format_datetime(context.test_start_time),
                "end_time": format_datetime(context.test_end_time),
            }

            with open(test_time_file, "w") as f:
                json.dump(test_time_data, f, indent=2)
            logger.info(f"Test execution time window saved to: {test_time_file}")
        except Exception as e:
            logger.warning(f"Failed to save test execution time: {e}")
    else:
        logger.debug("Test execution time not available (before_all may have failed before recording start time)")

    # Close all gRPC client connections
    # Only close clients that were successfully initialized (before_all may have failed)
    client_attrs = [
        'product_catalog_client',
        'cart_client',
        'recommendation_client',
        'currency_client',
        'checkout_client',
        'payment_client',
        'shipping_client',
        'email_client',
        'ad_client',
    ]

    for client_attr in client_attrs:
        if hasattr(context, client_attr):
            try:
                client = getattr(context, client_attr)
                client.close()
            except Exception as e:
                logger.warning(f"Error closing {client_attr}: {str(e)}")

    logger.info("All clients closed")
    logger.info("="*60)
    logger.info("")
