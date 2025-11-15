"""PaymentService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class PaymentServiceClient(BaseGrpcClient):
    """Client for PaymentService."""

    def __init__(self):
        super().__init__('payment', demo_pb2_grpc.PaymentServiceStub)

    def charge(self, amount, credit_card):
        """Charge a credit card.

        Args:
            amount: Money object representing the amount to charge
            credit_card: CreditCardInfo object with card details

        Returns:
            ChargeResponse: Response containing transaction ID

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.ChargeRequest(
            amount=amount,
            credit_card=credit_card
        )
        logger.info(f"Calling Charge(amount={amount.units}.{amount.nanos} {amount.currency_code})")
        response = self.stub.Charge(request, timeout=self.timeout)
        logger.info(f"Payment charged successfully: transaction_id={response.transaction_id}")
        return response
