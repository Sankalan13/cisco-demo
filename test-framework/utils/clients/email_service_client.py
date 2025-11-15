"""EmailService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class EmailServiceClient(BaseGrpcClient):
    """Client for EmailService."""

    def __init__(self):
        super().__init__('email', demo_pb2_grpc.EmailServiceStub)

    def send_order_confirmation(self, email, order):
        """Send order confirmation email.

        Args:
            email: Email address to send confirmation to
            order: OrderResult object containing order details

        Returns:
            Empty: Empty response on success

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.SendOrderConfirmationRequest(
            email=email,
            order=order
        )
        logger.info(f"Calling SendOrderConfirmation(email={email}, order_id={order.order_id})")
        response = self.stub.SendOrderConfirmation(request, timeout=self.timeout)
        logger.info(f"Order confirmation email sent successfully to {email}")
        return response
