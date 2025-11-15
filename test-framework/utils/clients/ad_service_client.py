"""AdService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class AdServiceClient(BaseGrpcClient):
    """Client for AdService."""

    def __init__(self):
        super().__init__('ad', demo_pb2_grpc.AdServiceStub)

    def get_ads(self, context_keys):
        """Get contextual advertisements.

        Args:
            context_keys: List of context keywords for ad targeting

        Returns:
            AdResponse: Response containing list of advertisements

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.AdRequest(context_keys=context_keys)
        logger.info(f"Calling GetAds(context_keys={context_keys})")
        response = self.stub.GetAds(request, timeout=self.timeout)
        logger.info(f"Received {len(response.ads)} advertisements")
        return response
