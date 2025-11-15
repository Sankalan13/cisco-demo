"""Base gRPC client class."""

import grpc
import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Import generated proto files
from generated.grpc.health.v1 import health_pb2, health_pb2_grpc

from utils.config_loader import get_config

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BaseGrpcClient:
    """Base class for gRPC service clients."""

    def __init__(self, service_name, stub_class):
        """Initialize gRPC client.

        Args:
            service_name: Name of service in config (e.g., 'productcatalog')
            stub_class: gRPC stub class for the service
        """
        self.config = get_config()
        self.service_name = service_name
        self.endpoint = self.config.get_service_endpoint(service_name)
        self.timeout = self.config.get_test_config('timeout')

        # Create gRPC channel and stub
        self.channel = grpc.insecure_channel(self.endpoint)
        self.stub = stub_class(self.channel)
        self.health_stub = health_pb2_grpc.HealthStub(self.channel)

        logger.info(f"Initialized {self.__class__.__name__} for {self.endpoint}")

    def check_health(self):
        """Check if service is healthy using gRPC health check.

        Returns:
            bool: True if service is healthy, False otherwise
        """
        try:
            request = health_pb2.HealthCheckRequest(service="")
            response = self.health_stub.Check(request, timeout=self.timeout)
            is_healthy = response.status == health_pb2.HealthCheckResponse.SERVING
            logger.info(f"{self.service_name} health check: {'HEALTHY' if is_healthy else 'UNHEALTHY'}")
            return is_healthy
        except grpc.RpcError as e:
            logger.warning(f"{self.service_name} health check failed: {e.code()}")
            return False

    def close(self):
        """Close the gRPC channel."""
        self.channel.close()
        logger.info(f"Closed connection to {self.service_name}")
