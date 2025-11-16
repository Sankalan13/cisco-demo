"""Step definitions for payment processing tests."""

import logging
from behave import when, then
from generated import demo_pb2
import grpc

logger = logging.getLogger(__name__)


@when('I charge {amount:f} "{currency_code}" with valid credit card')
def step_charge_with_valid_card(context, amount, currency_code):
    """Charge a payment with valid credit card."""
    # Create Money object for the charge amount
    units = int(amount)
    nanos = int((amount - units) * 1_000_000_000)

    money = demo_pb2.Money(
        currency_code=currency_code,
        units=units,
        nanos=nanos
    )

    # Create valid credit card
    credit_card = demo_pb2.CreditCardInfo(
        credit_card_number='4432-8015-6152-0454',
        credit_card_cvv=672,
        credit_card_expiration_month=1,
        credit_card_expiration_year=2030
    )

    try:
        response = context.payment_client.charge(money, credit_card)
        context.payment_response = response
        context.payment_successful = True
        logger.info(f"Payment charged: {amount} {currency_code}, transaction_id={response.transaction_id}")
    except grpc.RpcError as e:
        context.payment_successful = False
        context.grpc_error = e
        raise AssertionError(f"Failed to charge payment: {e.code()} - {e.details()}")


@when('I charge {amount:f} "{currency_code}" with credit card number "{card_number}"')
def step_charge_with_specific_card(context, amount, currency_code, card_number):
    """Charge a payment with a specific credit card number."""
    # Create Money object for the charge amount
    units = int(amount)
    nanos = int((amount - units) * 1_000_000_000)

    money = demo_pb2.Money(
        currency_code=currency_code,
        units=units,
        nanos=nanos
    )

    # Create credit card with specified number
    credit_card = demo_pb2.CreditCardInfo(
        credit_card_number=card_number,
        credit_card_cvv=123,
        credit_card_expiration_month=12,
        credit_card_expiration_year=2029
    )

    try:
        response = context.payment_client.charge(money, credit_card)
        context.payment_response = response
        context.payment_successful = True
        logger.info(f"Payment charged: {amount} {currency_code}, card={card_number}, transaction_id={response.transaction_id}")
    except grpc.RpcError as e:
        context.payment_successful = False
        context.grpc_error = e
        raise AssertionError(f"Failed to charge payment: {e.code()} - {e.details()}")


@then('the payment should be successful')
def step_verify_payment_successful(context):
    """Verify that the payment was successful."""
    assert context.payment_successful, "Payment failed"
    assert context.payment_response is not None, "Payment response is None"
    logger.info("✓ Payment was successful")


@then('I should receive a transaction ID')
def step_verify_transaction_id(context):
    """Verify that a transaction ID was received."""
    assert context.payment_response is not None, "Payment response is None"
    assert context.payment_response.transaction_id, "Transaction ID is empty"
    assert len(context.payment_response.transaction_id) > 0, "Transaction ID has no length"
    logger.info(f"✓ Received transaction ID: {context.payment_response.transaction_id}")
