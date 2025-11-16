"""Step definitions for Recommendation Service tests."""

import logging
from behave import when, then
import grpc

logger = logging.getLogger(__name__)


@when('I request recommendations based on my cart')
def step_get_recommendations(context):
    """Get product recommendations based on cart contents."""
    assert context.cart is not None, "Cart is None"
    assert context.user_id is not None, "No user ID available"

    # Extract product IDs from cart
    product_ids = [item.product_id for item in context.cart.items]

    try:
        response = context.recommendation_client.list_recommendations(
            user_id=context.user_id,
            product_ids=product_ids
        )
        context.recommendations = response.product_ids
        logger.info(f"Received {len(context.recommendations)} product recommendations")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to get recommendations: {e.code()} - {e.details()}")


@when('I get product recommendations')
def step_get_recommendations_simple(context):
    """Get product recommendations for current user."""
    assert context.user_id is not None, "No user ID available"

    # Get current cart to use for recommendations
    cart = context.cart_client.get_cart(context.user_id)
    product_ids = [item.product_id for item in cart.items]

    try:
        response = context.recommendation_client.list_recommendations(
            user_id=context.user_id,
            product_ids=product_ids
        )
        context.recommendations = response.product_ids
        logger.info(f"Received {len(context.recommendations)} product recommendations")
    except grpc.RpcError as e:
        context.grpc_error = e
        raise AssertionError(f"Failed to get recommendations: {e.code()} - {e.details()}")


@then('I should receive product recommendations')
def step_verify_recommendations_received(context):
    """Verify that recommendations were received."""
    assert context.recommendations is not None, "Recommendations are None"
    assert len(context.recommendations) > 0, "No recommendations received"

    logger.info(f"✓ Received {len(context.recommendations)} recommendations:")
    for i, product_id in enumerate(context.recommendations, 1):
        logger.info(f"  {i}. Product ID: {product_id}")


@then('the recommendations should not include products already in my cart')
def step_verify_recommendations_exclude_cart(context):
    """Verify that recommendations don't include products already in cart."""
    assert context.recommendations is not None, "Recommendations are None"

    # Get cart product IDs
    cart = context.cart_client.get_cart(context.user_id)
    cart_product_ids = [item.product_id for item in cart.items]

    # Check that no recommendations are in the cart
    for rec_id in context.recommendations:
        assert rec_id not in cart_product_ids, \
            f"Recommendation {rec_id} is already in cart"

    logger.info("✓ Recommendations don't include products already in cart")
