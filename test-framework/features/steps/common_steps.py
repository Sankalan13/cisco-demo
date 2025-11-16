"""Common step definitions used across multiple feature files."""

import logging
import uuid
from behave import given, when, then
from generated import demo_pb2
import grpc

logger = logging.getLogger(__name__)


@given('the microservices are healthy and running')
def step_verify_microservices_healthy(context):
    """Verify that all microservices are healthy and running."""
    # Check ProductCatalogService health
    try:
        # Use product_catalog_client's list_products method (no parameters needed)
        products = context.product_catalog_client.list_products()
        assert len(products.products) > 0, "ProductCatalogService returned no products"
        logger.info("✓ ProductCatalogService is healthy")
    except Exception as e:
        raise AssertionError(f"ProductCatalogService health check failed: {str(e)}")

    # Check CartService health
    try:
        test_user_id = str(uuid.uuid4())
        cart = context.cart_client.get_cart(test_user_id)
        assert cart is not None, "CartService returned None"
        logger.info("✓ CartService is healthy")
    except Exception as e:
        raise AssertionError(f"CartService health check failed: {str(e)}")

    # Check ShippingService health (using context.shipping_client if available)
    if hasattr(context, 'shipping_client'):
        try:
            # Create a minimal shipping quote request
            address = demo_pb2.Address(
                street_address="123 Test St",
                city="Test City",
                state="CA",
                country="United States",
                zip_code=12345
            )
            # Use shipping_client's get_quote method with separate parameters
            quote = context.shipping_client.get_quote(address, [])
            assert quote is not None, "ShippingService returned None"
            logger.info("✓ ShippingService is healthy")
        except Exception as e:
            raise AssertionError(f"ShippingService health check failed: {str(e)}")

    # Check CheckoutService health (using context.checkout_client if available)
    if hasattr(context, 'checkout_client'):
        logger.info("✓ CheckoutService client is available")

    logger.info("✓ All microservices are healthy and running")


@given('I have a unique user ID')
def step_create_unique_user_id(context):
    """Create a unique user ID for the scenario."""
    context.user_id = str(uuid.uuid4())
    logger.info(f"Created unique user ID: {context.user_id}")


@given('I add product "{product_id}" to my cart with quantity {quantity:d}')
@when('I add product "{product_id}" to my cart with quantity {quantity:d}')
def step_add_product_to_cart_by_id(context, product_id, quantity):
    """Add a specific product to the cart by ID."""
    # Ensure user_id exists
    if not hasattr(context, 'user_id'):
        context.user_id = str(uuid.uuid4())

    try:
        # Use the cart_client's add_item method with separate parameters
        context.cart_client.add_item(context.user_id, product_id, quantity)
        logger.info(f"Added {quantity}x {product_id} to cart for user {context.user_id}")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to add item to cart: {e.code()} - {e.details()}")
