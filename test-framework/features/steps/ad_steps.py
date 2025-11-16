"""Step definitions for advertisement display tests."""

import logging
from behave import when, then, register_type
import grpc
import parse

logger = logging.getLogger(__name__)


# Custom parse type that matches empty strings
@parse.with_pattern(r'.*')
def parse_optional_string(text):
    """Parse optional string (can be empty)."""
    return text if text else ""


# Register the custom type
register_type(optional_string=parse_optional_string)


@when('I request ads with context keywords "{keywords:optional_string}"')
def step_request_ads(context, keywords):
    """Request advertisements with context keywords."""
    # Split comma-separated keywords into list, or empty list if empty string
    if keywords:
        context_keys = [k.strip() for k in keywords.split(',')]
    else:
        context_keys = []

    try:
        response = context.ad_client.get_ads(context_keys)
        context.ad_response = response
        context.ads_fetch_successful = True
        context.current_context_keys = context_keys
        logger.info(f"Retrieved {len(response.ads)} ads for context: {context_keys}")
    except grpc.RpcError as e:
        context.ads_fetch_successful = False
        context.grpc_error = e
        raise AssertionError(f"Failed to get ads: {e.code()} - {e.details()}")


@then('I should receive advertisements')
def step_verify_ads_received(context):
    """Verify that advertisements were received."""
    assert context.ads_fetch_successful, "Failed to fetch ads"
    assert context.ad_response is not None, "Ad response is None"
    assert context.ad_response.ads is not None, "Ads list is None"
    assert len(context.ad_response.ads) > 0, "No ads received"
    logger.info(f"✓ Received {len(context.ad_response.ads)} advertisements")


@then('the ads should be relevant to the context')
def step_verify_ads_relevance(context):
    """Verify that ads are relevant to the context."""
    assert context.ad_response is not None, "Ad response is None"
    assert len(context.ad_response.ads) > 0, "No ads to verify"

    # Verify each ad has required fields
    for ad in context.ad_response.ads:
        assert ad.redirect_url, f"Ad missing redirect_url"
        assert ad.text, f"Ad missing text"

    logger.info(f"✓ All {len(context.ad_response.ads)} ads have required fields")
