from behave import given, when, then
from generated import demo_pb2


@given('I have items in my cart')
def step_have_items_in_cart(context):
    """Ensure the cart has at least one item."""
    # If user_id not set, create one
    if not hasattr(context, 'user_id'):
        import uuid
        context.user_id = str(uuid.uuid4())

    # Check current cart
    cart = context.cart_client.get_cart(context.user_id)

    # If cart is empty, add a default item
    if len(cart.items) == 0:
        # Use cart_client's add_item method with separate parameters
        context.cart_client.add_item(context.user_id, "OLJCESPC7Z", 1)


@given('my cart is empty')
def step_ensure_cart_empty(context):
    """Ensure the cart is empty."""
    # If user_id not set, create one
    if not hasattr(context, 'user_id'):
        import uuid
        context.user_id = str(uuid.uuid4())

    # Empty the cart using cart_client's empty_cart method
    context.cart_client.empty_cart(context.user_id)


@when('I request a shipping quote for the following address')
def step_request_shipping_quote(context):
    """Request a shipping quote for the given address."""
    # Parse address from table
    address_data = {}
    for row in context.table:
        address_data[row['field']] = row['value']

    # Create address
    address = demo_pb2.Address(
        street_address=address_data.get('street_address'),
        city=address_data.get('city'),
        state=address_data.get('state'),
        country=address_data.get('country'),
        zip_code=int(address_data.get('zip_code'))
    )

    # Get current cart items
    cart = context.cart_client.get_cart(context.user_id)

    try:
        # Use shipping_client's get_quote method with separate parameters
        response = context.shipping_client.get_quote(address, cart.items)
        context.shipping_quote = response.cost_usd
        context.shipping_quote_successful = True
    except Exception as e:
        context.shipping_error = str(e)
        context.shipping_quote_successful = False


@then('I should receive a shipping quote')
def step_verify_shipping_quote_received(context):
    """Verify that shipping quote was received."""
    assert context.shipping_quote_successful, \
        f"Shipping quote failed: {getattr(context, 'shipping_error', 'Unknown error')}"
    assert context.shipping_quote is not None, "Shipping quote is None"


@then('the quote should have a valid cost')
def step_verify_valid_cost(context):
    """Verify that shipping quote has a valid cost."""
    assert context.shipping_quote.currency_code, "Shipping quote missing currency code"
    # Cost should be non-negative
    total_cost = context.shipping_quote.units + (context.shipping_quote.nanos / 1e9)
    assert total_cost >= 0, f"Shipping cost should be non-negative, got {total_cost}"


@then('the quote should be in "{currency}" currency')
def step_verify_currency(context, currency):
    """Verify that shipping quote is in the expected currency."""
    assert context.shipping_quote.currency_code == currency, \
        f"Expected currency {currency}, got {context.shipping_quote.currency_code}"


@then('I store the shipping cost as "{variable_name}"')
def step_store_shipping_cost(context, variable_name):
    """Store the current shipping cost for later comparison."""
    if not hasattr(context, 'stored_values'):
        context.stored_values = {}

    total_cost = context.shipping_quote.units + (context.shipping_quote.nanos / 1e9)
    context.stored_values[variable_name] = total_cost


@then('the shipping cost should be different from "{variable_name}"')
def step_verify_cost_different(context, variable_name):
    """Verify that current shipping cost differs from stored value."""
    assert hasattr(context, 'stored_values'), "No stored values found"
    assert variable_name in context.stored_values, f"Variable {variable_name} not found in stored values"

    stored_cost = context.stored_values[variable_name]
    current_cost = context.shipping_quote.units + (context.shipping_quote.nanos / 1e9)

    assert current_cost != stored_cost, \
        f"Shipping cost should be different. Both are {current_cost}"


@then('the quote should have a currency code')
def step_verify_has_currency_code(context):
    """Verify that shipping quote has a currency code."""
    assert context.shipping_quote.currency_code, "Shipping quote missing currency_code field"
    assert len(context.shipping_quote.currency_code) > 0, "Currency code should not be empty"


@then('the quote should have units')
def step_verify_has_units(context):
    """Verify that shipping quote has units field."""
    assert hasattr(context.shipping_quote, 'units'), "Shipping quote missing units field"
    assert context.shipping_quote.units >= 0, "Units should be non-negative"


@then('the quote should have nanos')
def step_verify_has_nanos(context):
    """Verify that shipping quote has nanos field."""
    assert hasattr(context.shipping_quote, 'nanos'), "Shipping quote missing nanos field"
    assert 0 <= context.shipping_quote.nanos < 1000000000, \
        f"Nanos should be between 0 and 999999999, got {context.shipping_quote.nanos}"


@when('I ship an order to the following address')
def step_ship_order(context):
    """Ship an order to the given address."""
    # Parse address from table
    address_data = {}
    for row in context.table:
        address_data[row['field']] = row['value']

    # Create address
    address = demo_pb2.Address(
        street_address=address_data.get('street_address'),
        city=address_data.get('city'),
        state=address_data.get('state'),
        country=address_data.get('country'),
        zip_code=int(address_data.get('zip_code'))
    )

    # Get current cart items
    cart = context.cart_client.get_cart(context.user_id)

    try:
        # Use shipping_client's ship_order method
        response = context.shipping_client.ship_order(address, cart.items)
        context.ship_order_response = response
        context.ship_order_successful = True
    except Exception as e:
        context.shipping_error = str(e)
        context.ship_order_successful = False


@then('the order should be shipped successfully')
def step_verify_order_shipped(context):
    """Verify that the order was shipped successfully."""
    assert context.ship_order_successful, \
        f"Ship order failed: {getattr(context, 'shipping_error', 'Unknown error')}"
    assert context.ship_order_response is not None, "Ship order response is None"


@then('I should receive a tracking ID')
def step_verify_tracking_id(context):
    """Verify that a tracking ID was received."""
    assert context.ship_order_response is not None, "Ship order response is None"
    assert context.ship_order_response.tracking_id, "Tracking ID is empty"
    assert len(context.ship_order_response.tracking_id) > 0, "Tracking ID has no length"
