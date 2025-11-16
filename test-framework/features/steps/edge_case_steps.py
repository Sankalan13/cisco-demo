"""Step definitions for edge case tests."""

import logging
from behave import given, when, then
import grpc

logger = logging.getLogger(__name__)


@given('I have a user ID "{user_id}"')
def step_set_specific_user_id(context, user_id):
    """Set a specific user ID for testing."""
    context.user_id = user_id
    logger.info(f"Set user ID to: {user_id}")


@when('I get product details for "{product_id}"')
def step_get_product_details(context, product_id):
    """Get details for a specific product."""
    try:
        product = context.product_catalog_client.get_product(product_id)
        context.current_product = product
        context.product_fetch_successful = True
        logger.info(f"Retrieved product: {product.name}")
    except grpc.RpcError as e:
        context.product_fetch_successful = False
        context.grpc_error = e
        raise AssertionError(f"Failed to get product: {e.code()} - {e.details()}")


@then('the product should have valid details')
def step_verify_product_details(context):
    """Verify that product has all required details."""
    assert context.product_fetch_successful, "Product fetch failed"
    assert context.current_product is not None, "Product is None"

    product = context.current_product

    # Verify all required fields
    assert product.id, "Product missing ID"
    assert product.name, "Product missing name"
    assert product.description, "Product missing description"
    assert product.picture, "Product missing picture"
    assert product.price_usd, "Product missing price"
    assert product.price_usd.currency_code == "USD", \
        f"Expected USD currency, got {product.price_usd.currency_code}"
    assert product.price_usd.units >= 0, "Product price units should be non-negative"
    assert len(product.categories) > 0, "Product should have at least one category"

    logger.info(f"✓ Product {product.id} has valid details")
