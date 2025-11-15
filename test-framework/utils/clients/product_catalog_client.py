"""ProductCatalogService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class ProductCatalogClient(BaseGrpcClient):
    """Client for ProductCatalogService."""

    def __init__(self):
        super().__init__('productcatalog', demo_pb2_grpc.ProductCatalogServiceStub)

    def list_products(self):
        """List all products.

        Returns:
            ListProductsResponse: Response containing list of products

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.Empty()
        logger.info("Calling ListProducts()")
        response = self.stub.ListProducts(request, timeout=self.timeout)
        logger.info(f"Received {len(response.products)} products")
        return response

    def get_product(self, product_id):
        """Get a specific product by ID.

        Args:
            product_id: Product ID to retrieve

        Returns:
            Product: Product information

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.GetProductRequest(id=product_id)
        logger.info(f"Calling GetProduct(id={product_id})")
        response = self.stub.GetProduct(request, timeout=self.timeout)
        logger.info(f"Received product: {response.name}")
        return response

    def search_products(self, query):
        """Search for products.

        Args:
            query: Search query string

        Returns:
            SearchProductsResponse: Response containing matching products

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.SearchProductsRequest(query=query)
        logger.info(f"Calling SearchProducts(query='{query}')")
        response = self.stub.SearchProducts(request, timeout=self.timeout)
        logger.info(f"Found {len(response.results)} matching products")
        return response
