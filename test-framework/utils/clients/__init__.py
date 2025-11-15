"""gRPC client wrappers for microservices-demo services."""

from .base_client import BaseGrpcClient
from .product_catalog_client import ProductCatalogClient
from .cart_service_client import CartServiceClient
from .recommendation_service_client import RecommendationServiceClient
from .currency_service_client import CurrencyServiceClient
from .checkout_service_client import CheckoutServiceClient
from .payment_service_client import PaymentServiceClient
from .shipping_service_client import ShippingServiceClient
from .email_service_client import EmailServiceClient
from .ad_service_client import AdServiceClient

__all__ = [
    'BaseGrpcClient',
    'ProductCatalogClient',
    'CartServiceClient',
    'RecommendationServiceClient',
    'CurrencyServiceClient',
    'CheckoutServiceClient',
    'PaymentServiceClient',
    'ShippingServiceClient',
    'EmailServiceClient',
    'AdServiceClient',
]
