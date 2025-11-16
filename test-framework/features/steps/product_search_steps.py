from behave import given, when, then
from generated import demo_pb2


@when('I search for products with keyword "{keyword}"')
def step_search_products(context, keyword):
    """Search for products using the given keyword."""
    try:
        # Use product_catalog_client's search_products method with query string
        response = context.product_catalog_client.search_products(keyword)
        context.search_results = response.results
        context.search_successful = True
    except Exception as e:
        context.search_error = str(e)
        context.search_successful = False
        context.search_results = []


@when('I search for products with an empty keyword')
def step_search_products_empty(context):
    """Search for products using an empty keyword (should return all products)."""
    try:
        # Use product_catalog_client's search_products method with empty string
        response = context.product_catalog_client.search_products("")
        context.search_results = response.results
        context.search_successful = True
    except Exception as e:
        context.search_error = str(e)
        context.search_successful = False
        context.search_results = []


@then('I should receive search results')
def step_verify_search_results(context):
    """Verify that search returned results."""
    assert context.search_successful, f"Search failed: {getattr(context, 'search_error', 'Unknown error')}"
    assert len(context.search_results) > 0, "Expected search results but got none"


@then('the results should contain products matching "{keyword}"')
def step_verify_search_matches_keyword(context, keyword):
    """Verify that search results match the keyword (case-insensitive)."""
    keyword_lower = keyword.lower()

    for product in context.search_results:
        # Check if keyword appears in name, description, or categories
        name_match = keyword_lower in product.name.lower()
        desc_match = keyword_lower in product.description.lower()
        category_match = any(keyword_lower in cat.lower() for cat in product.categories)

        # At least one field should match
        assert name_match or desc_match or category_match, \
            f"Product '{product.name}' does not match keyword '{keyword}'"


@then('all returned products should have valid product information')
def step_verify_product_information(context):
    """Verify that all products have required fields populated."""
    for product in context.search_results:
        assert product.id, "Product missing ID"
        assert product.name, "Product missing name"
        assert product.description, "Product missing description"
        assert product.picture, "Product missing picture"
        assert product.price_usd, "Product missing price"
        assert product.price_usd.currency_code == "USD", f"Expected USD currency, got {product.price_usd.currency_code}"
        assert product.price_usd.units >= 0, "Product price units should be non-negative"
        assert len(product.categories) > 0, "Product should have at least one category"


@then('I should receive an empty result set')
def step_verify_empty_results(context):
    """Verify that search returned no results."""
    assert context.search_successful, f"Search failed: {getattr(context, 'search_error', 'Unknown error')}"
    assert len(context.search_results) == 0, f"Expected no results but got {len(context.search_results)}"


@then('I should receive all available products')
def step_verify_all_products_returned(context):
    """Verify that search returned all products (empty search string)."""
    assert context.search_successful, f"Search failed: {getattr(context, 'search_error', 'Unknown error')}"
    assert len(context.search_results) > 0, "Expected all products but got none"

    # Get full catalog to compare (no parameters needed)
    full_catalog = context.product_catalog_client.list_products()

    # Empty search should return same count as full catalog
    assert len(context.search_results) == len(full_catalog.products), \
        f"Empty search returned {len(context.search_results)} products but catalog has {len(full_catalog.products)}"


@then('each product should have the following fields')
def step_verify_product_fields(context):
    """Verify that each product has all required fields."""
    required_fields = [row['field'] for row in context.table]

    assert len(context.search_results) > 0, "No search results to verify"

    for product in context.search_results:
        for field in required_fields:
            if field == 'id':
                assert product.id, f"Product missing {field}"
            elif field == 'name':
                assert product.name, f"Product missing {field}"
            elif field == 'description':
                assert product.description, f"Product missing {field}"
            elif field == 'picture':
                assert product.picture, f"Product missing {field}"
            elif field == 'price_usd':
                assert product.price_usd, f"Product missing {field}"
                assert product.price_usd.currency_code, f"Product price missing currency_code"
            elif field == 'categories':
                assert len(product.categories) > 0, f"Product missing {field}"
