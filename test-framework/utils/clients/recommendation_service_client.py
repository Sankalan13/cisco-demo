"""RecommendationService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class RecommendationServiceClient(BaseGrpcClient):
    """Client for RecommendationService."""

    def __init__(self):
        super().__init__('recommendation', demo_pb2_grpc.RecommendationServiceStub)

    def list_recommendations(self, user_id, product_ids):
        """Get product recommendations.

        Args:
            user_id: User ID
            product_ids: List of product IDs for context

        Returns:
            ListRecommendationsResponse: Response containing recommended products

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.ListRecommendationsRequest(
            user_id=user_id,
            product_ids=product_ids
        )
        logger.info(f"Calling ListRecommendations(user_id={user_id}, product_ids={product_ids})")
        response = self.stub.ListRecommendations(request, timeout=self.timeout)
        logger.info(f"Received {len(response.product_ids)} recommendations")
        return response
