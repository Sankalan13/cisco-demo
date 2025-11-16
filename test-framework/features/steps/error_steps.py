"""Step definitions for error handling tests."""

import logging
from behave import when, then
from generated import demo_pb2
import grpc

logger = logging.getLogger(__name__)


@when('I try to get product with ID "{product_id}"')
def step_try_get_invalid_product(context, product_id):
    """Try to get a product that doesn't exist."""
    try:
        product = context.product_catalog_client.get_product(product_id)
        context.error_occurred = False
        context.retrieved_product = product
    except grpc.RpcError as e:
        context.error_occurred = True
        context.grpc_error = e
        context.error_code = e.code()
        logger.info(f"Received expected error: {e.code()} - {e.details()}")


@when('I try to add product "{product_id}" to my cart with quantity {quantity:d}')
def step_try_add_invalid_product(context, product_id, quantity):
    """Try to add an invalid product to cart."""
    if not hasattr(context, 'user_id'):
        import uuid
        context.user_id = str(uuid.uuid4())

    try:
        context.cart_client.add_item(context.user_id, product_id, quantity)
        context.error_occurred = False
    except grpc.RpcError as e:
        context.error_occurred = True
        context.grpc_error = e
        context.error_code = e.code()
        logger.info(f"Received expected error: {e.code()} - {e.details()}")


@when('I try to place an order with invalid credit card "{card_number}"')
def step_try_checkout_invalid_card(context, card_number):
    """Try to checkout with an invalid credit card."""
    address = demo_pb2.Address(
        street_address='1600 Amphitheatre Parkway',
        city='Mountain View',
        state='CA',
        country='United States',
        zip_code=94043
    )

    credit_card = demo_pb2.CreditCardInfo(
        credit_card_number=card_number,
        credit_card_cvv=123,
        credit_card_expiration_month=12,
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
        context.error_occurred = False
        context.order_response = response
    except grpc.RpcError as e:
        context.error_occurred = True
        context.grpc_error = e
        context.error_code = e.code()
        logger.info(f"Received expected error: {e.code()} - {e.details()}")


@when('I try to place an order with expired credit card year {year:d}')
def step_try_checkout_expired_card(context, year):
    """Try to checkout with an expired credit card."""
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
        credit_card_expiration_year=year
    )

    try:
        response = context.checkout_client.place_order(
            user_id=context.user_id,
            user_currency='USD',
            address=address,
            email='test@example.com',
            credit_card=credit_card
        )
        context.error_occurred = False
        context.order_response = response
    except grpc.RpcError as e:
        context.error_occurred = True
        context.grpc_error = e
        context.error_code = e.code()
        context.error_details = e.details()
        logger.info(f"Received expected error: {e.code()} - {e.details()}")


@when('I try to request shipping quote with empty city')
def step_try_shipping_invalid_address(context):
    """Try to get shipping quote with invalid address."""
    address = demo_pb2.Address(
        street_address='123 Test St',
        city='',  # Empty city
        state='CA',
        country='United States',
        zip_code=12345
    )

    cart = context.cart_client.get_cart(context.user_id)

    try:
        response = context.shipping_client.get_quote(address, cart.items)
        context.error_occurred = False
        context.shipping_quote = response.cost_usd
    except grpc.RpcError as e:
        context.error_occurred = True
        context.grpc_error = e
        context.error_code = e.code()
        logger.info(f"Received expected error: {e.code()} - {e.details()}")


@when('I try to place an order with valid payment and shipping information')
def step_try_checkout_empty_cart(context):
    """Try to checkout with empty cart."""
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
        context.error_occurred = False
        context.order_response = response
    except grpc.RpcError as e:
        context.error_occurred = True
        context.grpc_error = e
        context.error_code = e.code()
        logger.info(f"Received expected error: {e.code()} - {e.details()}")


@then('I should receive a product not found error')
def step_verify_product_not_found_error(context):
    """Verify that a product not found error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    assert context.error_code == grpc.StatusCode.NOT_FOUND, \
        f"Expected NOT_FOUND error, got {context.error_code}"
    logger.info("✓ Received product not found error")


@then('I should receive an invalid product error')
def step_verify_invalid_product_error(context):
    """Verify that an invalid product error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    # Could be NOT_FOUND or INVALID_ARGUMENT depending on implementation
    assert context.error_code in [grpc.StatusCode.NOT_FOUND, grpc.StatusCode.INVALID_ARGUMENT], \
        f"Expected NOT_FOUND or INVALID_ARGUMENT error, got {context.error_code}"
    logger.info("✓ Received invalid product error")


@then('I should receive a payment error')
def step_verify_payment_error(context):
    """Verify that a payment error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    # Payment errors are typically INTERNAL or INVALID_ARGUMENT
    assert context.error_code in [grpc.StatusCode.INTERNAL, grpc.StatusCode.INVALID_ARGUMENT], \
        f"Expected payment error, got {context.error_code}"
    logger.info("✓ Received payment error")


@then('I should receive a credit card expired error')
def step_verify_expired_card_error(context):
    """Verify that a credit card expired error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    assert context.error_code == grpc.StatusCode.INTERNAL, \
        f"Expected INTERNAL error for expired card, got {context.error_code}"
    # Check that error message mentions expiration
    assert 'expired' in context.error_details.lower(), \
        f"Expected expiration error message, got: {context.error_details}"
    logger.info("✓ Received credit card expired error")


@then('I should receive an address validation error')
def step_verify_address_error(context):
    """Verify that an address validation error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    # Address validation errors could be INVALID_ARGUMENT or INTERNAL
    assert context.error_code in [grpc.StatusCode.INVALID_ARGUMENT, grpc.StatusCode.INTERNAL], \
        f"Expected address validation error, got {context.error_code}"
    logger.info("✓ Received address validation error")


@then('I should receive an empty cart error')
def step_verify_empty_cart_error(context):
    """Verify that an empty cart error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    assert context.error_code in [grpc.StatusCode.INVALID_ARGUMENT, grpc.StatusCode.FAILED_PRECONDITION], \
        f"Expected empty cart error, got {context.error_code}"
    logger.info("✓ Received empty cart error")


@then('I should receive an invalid quantity error')
def step_verify_invalid_quantity_error(context):
    """Verify that an invalid quantity error was received."""
    assert context.error_occurred, "Expected an error but none occurred"
    assert context.error_code == grpc.StatusCode.INVALID_ARGUMENT, \
        f"Expected INVALID_ARGUMENT error, got {context.error_code}"
    logger.info("✓ Received invalid quantity error")
