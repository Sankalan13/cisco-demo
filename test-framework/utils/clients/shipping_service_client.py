"""ShippingService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class ShippingServiceClient(BaseGrpcClient):
    """Client for ShippingService."""

    def __init__(self):
        super().__init__('shipping', demo_pb2_grpc.ShippingServiceStub)

    def get_quote(self, address, items):
        """Get shipping quote for items to an address.

        Args:
            address: Address object for destination
            items: List of CartItem objects

        Returns:
            GetQuoteResponse: Response containing shipping cost

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.GetQuoteRequest(
            address=address,
            items=items
        )
        logger.info(f"Calling GetQuote(address={address.city}, items_count={len(items)})")
        response = self.stub.GetQuote(request, timeout=self.timeout)
        cost = response.cost_usd
        logger.info(f"Shipping quote: {cost.units}.{cost.nanos} {cost.currency_code}")
        return response

    def ship_order(self, address, items):
        """Ship an order to an address.

        Args:
            address: Address object for destination
            items: List of CartItem objects

        Returns:
            ShipOrderResponse: Response containing tracking ID

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.ShipOrderRequest(
            address=address,
            items=items
        )
        logger.info(f"Calling ShipOrder(address={address.city}, items_count={len(items)})")
        response = self.stub.ShipOrder(request, timeout=self.timeout)
        logger.info(f"Order shipped successfully: tracking_id={response.tracking_id}")
        return response
