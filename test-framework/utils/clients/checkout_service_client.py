"""CheckoutService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class CheckoutServiceClient(BaseGrpcClient):
    """Client for CheckoutService."""

    def __init__(self):
        super().__init__('checkout', demo_pb2_grpc.CheckoutServiceStub)

    def place_order(self, user_id, user_currency, address, email, credit_card):
        """Place an order.

        Args:
            user_id: User ID
            user_currency: Currency code
            address: Address object
            email: Email address
            credit_card: CreditCardInfo object

        Returns:
            PlaceOrderResponse: Response containing order details

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.PlaceOrderRequest(
            user_id=user_id,
            user_currency=user_currency,
            address=address,
            email=email,
            credit_card=credit_card
        )
        logger.info(f"Calling PlaceOrder(user_id={user_id})")
        response = self.stub.PlaceOrder(request, timeout=self.timeout)
        logger.info(f"Order placed: {response.order.order_id}")
        return response
