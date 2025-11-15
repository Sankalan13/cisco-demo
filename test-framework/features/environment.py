"""Behave environment hooks for test setup and teardown."""

import sys
import time
import logging
from pathlib import Path
from datetime import datetime

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

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

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def before_all(context):
    """Set up test environment before all tests.

    This hook:
    - Initializes all gRPC clients
    - Performs health checks on all services
    - Fails fast if services are not healthy
    """
    logger.info("="*60)
    logger.info("Setting up test environment...")
    logger.info("="*60)

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

    # Initialize scenario-specific state
    context.products = None
    context.current_product = None
    context.cart = None
    context.recommendations = None


def after_scenario(context, scenario):
    """Clean up after each scenario.

    This hook:
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

    logger.info("-"*60)
    logger.info("")


def after_all(context):
    """Clean up after all tests.

    This hook:
    - Closes all gRPC client connections
    """
    logger.info("")
    logger.info("="*60)
    logger.info("Cleaning up test environment...")
    logger.info("="*60)

    # Close all gRPC client connections
    clients = [
        context.product_catalog_client,
        context.cart_client,
        context.recommendation_client,
        context.currency_client,
        context.checkout_client,
        context.payment_client,
        context.shipping_client,
        context.email_client,
        context.ad_client,
    ]

    for client in clients:
        try:
            client.close()
        except Exception as e:
            logger.warning(f"Error closing client: {str(e)}")

    logger.info("All clients closed")
    logger.info("="*60)
    logger.info("")
