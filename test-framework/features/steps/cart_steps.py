"""Step definitions for Cart Service tests."""

import logging
from behave import given, when, then, use_step_matcher
import grpc

logger = logging.getLogger(__name__)

# Use 'parse' matcher for parameterized steps
use_step_matcher("parse")


@when('I add the product to my cart with quantity {quantity:d}')
def step_add_product_to_cart(context, quantity):
    """Add a product to the cart with specified quantity."""
    assert context.current_product is not None, "No product selected to add to cart"
    assert context.user_id is not None, "No user ID available"

    product_id = context.current_product.id

    try:
        context.cart_client.add_item(
            user_id=context.user_id,
            product_id=product_id,
            quantity=quantity
        )
        logger.info(f"Added {quantity}x {context.current_product.name} to cart")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to add item to cart: {e.code()} - {e.details()}")


@then('the item should be added successfully')
def step_verify_item_added(context):
    """Verify that the item was added successfully (no errors)."""
    # If we got here without exception, the add was successful
    assert not hasattr(context, 'grpc_error'), \
        f"gRPC error occurred: {context.grpc_error if hasattr(context, 'grpc_error') else 'Unknown'}"
    logger.info("✓ Item added to cart successfully")


@when('I retrieve my cart contents')
def step_get_cart(context):
    """Retrieve cart contents for the current user."""
    assert context.user_id is not None, "No user ID available"

    try:
        response = context.cart_client.get_cart(context.user_id)
        context.cart = response
        logger.info(f"Retrieved cart with {len(response.items)} items")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to get cart: {e.code()} - {e.details()}")


@then('my cart should contain {item_count:d} item')
@then('my cart should contain {item_count:d} items')
def step_verify_cart_item_count(context, item_count):
    """Verify that the cart contains the expected number of items."""
    assert context.cart is not None, "Cart is None"
    actual_count = len(context.cart.items)
    assert actual_count == item_count, \
        f"Expected {item_count} items in cart, but found {actual_count}"
    logger.info(f"✓ Cart contains {item_count} item(s)")


@then('the item quantity should be {expected_quantity:d}')
def step_verify_item_quantity(context, expected_quantity):
    """Verify that the first item in cart has the expected quantity."""
    assert context.cart is not None, "Cart is None"
    assert len(context.cart.items) > 0, "Cart is empty"

    first_item = context.cart.items[0]
    actual_quantity = first_item.quantity

    assert actual_quantity == expected_quantity, \
        f"Expected quantity {expected_quantity}, but found {actual_quantity}"
    logger.info(f"✓ Item quantity is {expected_quantity}")


@then('the product ID in the cart should match the added product')
def step_verify_product_id_in_cart(context):
    """Verify that the product ID in the cart matches the added product."""
    assert context.cart is not None, "Cart is None"
    assert len(context.cart.items) > 0, "Cart is empty"
    assert context.current_product is not None, "No current product to compare"

    cart_product_id = context.cart.items[0].product_id
    expected_product_id = context.current_product.id

    assert cart_product_id == expected_product_id, \
        f"Expected product ID {expected_product_id}, but found {cart_product_id} in cart"
    logger.info(f"✓ Product ID in cart matches: {cart_product_id}")


@when('I empty my cart')
def step_empty_cart(context):
    """Empty the cart for the current user."""
    assert context.user_id is not None, "No user ID available"

    try:
        context.cart_client.empty_cart(context.user_id)
        logger.info(f"Emptied cart for user {context.user_id}")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to empty cart: {e.code()} - {e.details()}")


@then('the cart should have all added products')
def step_verify_all_products_in_cart(context):
    """Verify that cart contains all the products that were added."""
    assert context.cart is not None, "Cart is None"
    # This is a general verification that items exist in cart
    # More specific checks are done by item count verification
    assert len(context.cart.items) > 0, "Cart is empty but should have products"
    logger.info(f"✓ Cart has {len(context.cart.items)} products")


@then('the product "{product_id}" should have quantity {expected_quantity:d}')
def step_verify_specific_product_quantity(context, product_id, expected_quantity):
    """Verify that a specific product has the expected quantity in cart."""
    assert context.cart is not None, "Cart is None"

    # Find the product in cart
    found = False
    for item in context.cart.items:
        if item.product_id == product_id:
            found = True
            actual_quantity = item.quantity
            assert actual_quantity == expected_quantity, \
                f"Product {product_id} has quantity {actual_quantity}, expected {expected_quantity}"
            logger.info(f"✓ Product {product_id} has correct quantity: {expected_quantity}")
            break

    assert found, f"Product {product_id} not found in cart"


@then('the cart should contain product "{product_id}"')
def step_verify_cart_contains_product(context, product_id):
    """Verify that cart contains a specific product."""
    assert context.cart is not None, "Cart is None"

    product_ids = [item.product_id for item in context.cart.items]
    assert product_id in product_ids, \
        f"Product {product_id} not found in cart. Cart contains: {product_ids}"
    logger.info(f"✓ Cart contains product {product_id}")
