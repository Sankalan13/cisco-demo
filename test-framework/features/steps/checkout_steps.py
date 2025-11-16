"""
Step definitions for checkout and payment flow tests.
"""

from behave import given, when, then
import logging
from generated import demo_pb2

logger = logging.getLogger(__name__)


@when('I place an order with the following details')
def step_place_order_with_details(context):
    """Place an order with detailed shipping and payment information."""
    # Parse table data into a dictionary
    order_details = {}
    for row in context.table:
        order_details[row['field']] = row['value']

    # Create address
    address = demo_pb2.Address(
        street_address=order_details.get('street_address', '1600 Amphitheatre Parkway'),
        city=order_details.get('city', 'Mountain View'),
        state=order_details.get('state', 'CA'),
        country=order_details.get('country', 'United States'),
        zip_code=int(order_details.get('zip_code', 94043))
    )

    # Create credit card info
    credit_card = demo_pb2.CreditCardInfo(
        credit_card_number=order_details.get('card_number', '4432-8015-6152-0454'),
        credit_card_cvv=int(order_details.get('card_cvv', 672)),
        credit_card_expiration_month=int(order_details.get('card_exp_month', 1)),
        credit_card_expiration_year=int(order_details.get('card_exp_year', 2030))
    )

    # Place the order using checkout_client's place_order method with separate parameters
    try:
        response = context.checkout_client.place_order(
            user_id=context.user_id,
            user_currency=order_details.get('currency_code', 'USD'),
            address=address,
            email=order_details.get('email', 'test@example.com'),
            credit_card=credit_card
        )
        context.order_response = response
        context.order_placed_successfully = True
        logger.info(f"Order placed successfully: {response.order.order_id}")
        logger.info(f"Shipping tracking ID: {response.order.shipping_tracking_id}")
    except Exception as e:
        context.order_placed_successfully = False
        context.order_error = str(e)
        logger.error(f"Order placement failed: {e}")


@when('I place an order with {currency} currency and valid shipping and payment details')
def step_place_order_with_currency(context, currency):
    """Place an order with specified currency and default valid details."""
    address = demo_pb2.Address(
        street_address='1600 Amphitheatre Parkway',
        city='Mountain View',
        state='CA',
        country='United States',
        zip_code=94043
    )

    credit_card = demo_pb2.CreditCardInfo(
        credit_card_number='4432-8015-6152-0454',
        credit_card_cvv=672,
        credit_card_expiration_month=1,
        credit_card_expiration_year=2030
    )

    try:
        response = context.checkout_client.place_order(
            user_id=context.user_id,
            user_currency=currency,
            address=address,
            email='test@example.com',
            credit_card=credit_card
        )
        context.order_response = response
        context.order_placed_successfully = True
        context.order_currency = currency
        logger.info(f"Order placed with {currency}: {response.order.order_id}")
    except Exception as e:
        context.order_placed_successfully = False
        context.order_error = str(e)
        logger.error(f"Order placement failed: {e}")


@when('I place an order with valid payment and shipping information')
def step_place_order_with_defaults(context):
    """Place an order with default valid payment and shipping information."""
    address = demo_pb2.Address(
        street_address='1600 Amphitheatre Parkway',
        city='Mountain View',
        state='CA',
        country='United States',
        zip_code=94043
    )

    credit_card = demo_pb2.CreditCardInfo(
        credit_card_number='4432-8015-6152-0454',
        credit_card_cvv=672,
        credit_card_expiration_month=1,
        credit_card_expiration_year=2030
    )

    try:
        response = context.checkout_client.place_order(
            user_id=context.user_id,
            user_currency='USD',
            address=address,
            email='test@example.com',
            credit_card=credit_card
        )
        context.order_response = response
        context.order_placed_successfully = True
        logger.info(f"Order placed: {response.order.order_id}")
    except Exception as e:
        context.order_placed_successfully = False
        context.order_error = str(e)
        logger.error(f"Order placement failed: {e}")


@then('the order should be placed successfully')
def step_verify_order_success(context):
    """Verify that the order was placed successfully."""
    assert context.order_placed_successfully, \
        f"Order placement failed: {getattr(context, 'order_error', 'Unknown error')}"
    assert hasattr(context, 'order_response'), "No order response received"
    assert context.order_response.order.order_id, "Order ID is empty"
    logger.info("✓ Order placed successfully")


@then('I should receive an order ID')
def step_verify_order_id(context):
    """Verify that an order ID was returned."""
    assert hasattr(context, 'order_response'), "No order response"
    order_id = context.order_response.order.order_id
    assert order_id, "Order ID is empty"
    assert len(order_id) > 0, "Order ID should not be empty"
    logger.info(f"✓ Received order ID: {order_id}")


@then('I should receive an order ID in {currency}')
def step_verify_order_id_with_currency(context, currency):
    """Verify order ID and that response is in correct currency."""
    assert hasattr(context, 'order_response'), "No order response"
    order_id = context.order_response.order.order_id
    assert order_id, "Order ID is empty"

    # Verify items have correct currency
    for item in context.order_response.order.items:
        assert item.cost.currency_code == currency, \
            f"Expected currency {currency}, got {item.cost.currency_code}"

    logger.info(f"✓ Order ID: {order_id}, Currency: {currency}")


@then('I should receive a shipping tracking ID')
def step_verify_tracking_id(context):
    """Verify that a shipping tracking ID was returned."""
    assert hasattr(context, 'order_response'), "No order response"
    tracking_id = context.order_response.order.shipping_tracking_id
    assert tracking_id, "Shipping tracking ID is empty"
    assert len(tracking_id) > 0, "Tracking ID should not be empty"
    logger.info(f"✓ Received tracking ID: {tracking_id}")


@then('my cart should be empty')
def step_verify_cart_empty(context):
    """Verify that the cart was emptied after checkout."""
    # Get the cart to verify it's empty
    cart = context.cart_client.get_cart(context.user_id)
    assert len(cart.items) == 0, \
        f"Expected empty cart, but found {len(cart.items)} items"
    logger.info("✓ Cart is empty after checkout")


@then('the total cost should be in {currency}')
def step_verify_total_currency(context, currency):
    """Verify that the total cost is in the specified currency."""
    assert hasattr(context, 'order_response'), "No order response"
    shipping_cost = context.order_response.order.shipping_cost
    assert shipping_cost.currency_code == currency, \
        f"Expected shipping currency {currency}, got {shipping_cost.currency_code}"
    logger.info(f"✓ Total cost is in {currency}")
