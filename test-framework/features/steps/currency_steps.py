"""Step definitions for currency operations tests."""

import logging
from behave import when, then
from generated import demo_pb2
import grpc

logger = logging.getLogger(__name__)


@when('I request the list of supported currencies')
def step_get_supported_currencies(context):
    """Request list of supported currencies."""
    try:
        response = context.currency_client.get_supported_currencies()
        context.supported_currencies = response.currency_codes
        context.currency_fetch_successful = True
        logger.info(f"Retrieved {len(context.supported_currencies)} supported currencies")
    except grpc.RpcError as e:
        context.currency_fetch_successful = False
        context.grpc_error = e
        raise AssertionError(f"Failed to get supported currencies: {e.code()} - {e.details()}")


@when('I convert {amount:f} "{from_code}" to "{to_code}"')
def step_convert_currency(context, amount, from_code, to_code):
    """Convert currency from one to another."""
    # Create Money object for the source amount
    # Handle both integer and decimal amounts
    units = int(amount)
    nanos = int((amount - units) * 1_000_000_000)

    from_amount = demo_pb2.Money(
        currency_code=from_code,
        units=units,
        nanos=nanos
    )

    try:
        response = context.currency_client.convert(from_amount, to_code)
        context.converted_amount = response
        context.conversion_successful = True
        logger.info(f"Converted {amount} {from_code} to {response.units}.{response.nanos:09d} {response.currency_code}")
    except grpc.RpcError as e:
        context.conversion_successful = False
        context.grpc_error = e
        raise AssertionError(f"Failed to convert currency: {e.code()} - {e.details()}")


@then('I should receive a list of currency codes')
def step_verify_currency_list(context):
    """Verify that a list of currency codes was received."""
    assert context.currency_fetch_successful, "Failed to fetch currencies"
    assert context.supported_currencies is not None, "Currency list is None"
    assert len(context.supported_currencies) > 0, "Currency list is empty"
    logger.info(f"✓ Received {len(context.supported_currencies)} currency codes")


@then('the list should contain at least {count:d} currencies')
def step_verify_minimum_currencies(context, count):
    """Verify that the currency list contains at least the specified number of currencies."""
    assert len(context.supported_currencies) >= count, \
        f"Expected at least {count} currencies, got {len(context.supported_currencies)}"
    logger.info(f"✓ Currency list contains {len(context.supported_currencies)} currencies (>= {count})")


@then('the list should contain "{currency_code}"')
def step_verify_currency_in_list(context, currency_code):
    """Verify that a specific currency code is in the list."""
    assert currency_code in context.supported_currencies, \
        f"Expected {currency_code} in supported currencies, got {context.supported_currencies}"
    logger.info(f"✓ {currency_code} found in supported currencies")


@then('I should receive a valid conversion result')
def step_verify_conversion_result(context):
    """Verify that a valid conversion result was received."""
    assert context.conversion_successful, "Conversion failed"
    assert context.converted_amount is not None, "Converted amount is None"
    assert context.converted_amount.currency_code, "Converted amount missing currency code"
    logger.info("✓ Received valid conversion result")


@then('the converted amount should be in "{currency_code}"')
def step_verify_converted_currency(context, currency_code):
    """Verify that the converted amount is in the expected currency."""
    assert context.converted_amount.currency_code == currency_code, \
        f"Expected currency {currency_code}, got {context.converted_amount.currency_code}"
    logger.info(f"✓ Converted amount is in {currency_code}")


@then('the converted amount should be greater than {value:d}')
def step_verify_converted_amount_positive(context, value):
    """Verify that the converted amount is greater than zero."""
    total_value = context.converted_amount.units + (context.converted_amount.nanos / 1_000_000_000)
    assert total_value > value, \
        f"Expected converted amount > {value}, got {total_value}"
    logger.info(f"✓ Converted amount {total_value} > {value}")


@then('the converted amount should equal {units:d} units')
def step_verify_converted_amount_equals(context, units):
    """Verify that the converted amount equals the expected value."""
    # For same-currency conversion, amount should be the same
    assert context.converted_amount.units == units, \
        f"Expected {units} units, got {context.converted_amount.units}"
    assert context.converted_amount.nanos == 0, \
        f"Expected 0 nanos for whole units, got {context.converted_amount.nanos}"
    logger.info(f"✓ Converted amount equals {units} units")
