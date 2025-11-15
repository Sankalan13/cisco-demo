"""Step definitions for Product Catalog Service tests."""

import logging
from behave import given, when, then
import grpc

logger = logging.getLogger(__name__)


@when('I list all available products')
def step_list_products(context):
    """List all products from the product catalog."""
    try:
        response = context.product_catalog_client.list_products()
        context.products = response.products
        logger.info(f"Retrieved {len(context.products)} products")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to list products: {e.code()} - {e.details()}")


@then('I should receive a non-empty product list')
def step_verify_product_list_not_empty(context):
    """Verify that the product list is not empty."""
    assert context.products is not None, "Products list is None"
    assert len(context.products) > 0, "Products list is empty"
    logger.info(f"✓ Product list contains {len(context.products)} products")


@when('I get details for the first product')
def step_get_first_product(context):
    """Get details for the first product in the list."""
    assert context.products is not None and len(context.products) > 0, \
        "No products available to get details for"

    first_product = context.products[0]
    product_id = first_product.id

    try:
        response = context.product_catalog_client.get_product(product_id)
        context.current_product = response
        logger.info(f"Retrieved product details for: {response.name} (ID: {response.id})")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to get product {product_id}: {e.code()} - {e.details()}")


@then('I should receive complete product information')
def step_verify_product_information(context):
    """Verify that the product has complete information."""
    product = context.current_product
    assert product is not None, "Current product is None"

    # Verify all required fields are present
    assert product.id, "Product ID is missing"
    assert product.name, "Product name is missing"
    assert product.description, "Product description is missing"
    assert product.price_usd, "Product price is missing"

    # Verify price has valid currency
    assert product.price_usd.currency_code == "USD", \
        f"Expected currency USD, got {product.price_usd.currency_code}"

    logger.info(f"✓ Product has complete information:")
    logger.info(f"  ID: {product.id}")
    logger.info(f"  Name: {product.name}")
    logger.info(f"  Price: {product.price_usd.units}.{product.price_usd.nanos:09d} {product.price_usd.currency_code}")
    logger.info(f"  Categories: {', '.join(product.categories) if product.categories else 'None'}")
