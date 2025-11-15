"""CurrencyService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class CurrencyServiceClient(BaseGrpcClient):
    """Client for CurrencyService."""

    def __init__(self):
        super().__init__('currency', demo_pb2_grpc.CurrencyServiceStub)

    def get_supported_currencies(self):
        """Get list of supported currencies.

        Returns:
            GetSupportedCurrenciesResponse: Response containing currency codes

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.Empty()
        logger.info("Calling GetSupportedCurrencies()")
        response = self.stub.GetSupportedCurrencies(request, timeout=self.timeout)
        logger.info(f"Received {len(response.currency_codes)} supported currencies")
        return response

    def convert(self, from_amount, to_code):
        """Convert currency amount.

        Args:
            from_amount: Money object to convert
            to_code: Target currency code

        Returns:
            Money: Converted amount

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.CurrencyConversionRequest(
            from_=from_amount,
            to_code=to_code
        )
        logger.info(f"Calling Convert(from={from_amount.currency_code}, to={to_code})")
        response = self.stub.Convert(request, timeout=self.timeout)
        logger.info(f"Converted to {response.currency_code}")
        return response
