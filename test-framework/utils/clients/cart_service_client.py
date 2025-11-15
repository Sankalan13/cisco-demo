"""CartService gRPC client."""

import logging
from pathlib import Path
import sys

# Add generated directory to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from generated import demo_pb2, demo_pb2_grpc
from .base_client import BaseGrpcClient

logger = logging.getLogger(__name__)


class CartServiceClient(BaseGrpcClient):
    """Client for CartService."""

    def __init__(self):
        super().__init__('cart', demo_pb2_grpc.CartServiceStub)

    def add_item(self, user_id, product_id, quantity):
        """Add an item to the cart.

        Args:
            user_id: User ID
            product_id: Product ID to add
            quantity: Quantity of the product

        Returns:
            Empty: Empty response on success

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        item = demo_pb2.CartItem(product_id=product_id, quantity=quantity)
        request = demo_pb2.AddItemRequest(user_id=user_id, item=item)
        logger.info(f"Calling AddItem(user_id={user_id}, product_id={product_id}, quantity={quantity})")
        response = self.stub.AddItem(request, timeout=self.timeout)
        logger.info("Item added to cart successfully")
        return response

    def get_cart(self, user_id):
        """Get cart contents for a user.

        Args:
            user_id: User ID

        Returns:
            Cart: Cart contents

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.GetCartRequest(user_id=user_id)
        logger.info(f"Calling GetCart(user_id={user_id})")
        response = self.stub.GetCart(request, timeout=self.timeout)
        logger.info(f"Cart contains {len(response.items)} items")
        return response

    def empty_cart(self, user_id):
        """Empty cart for a user.

        Args:
            user_id: User ID

        Returns:
            Empty: Empty response on success

        Raises:
            grpc.RpcError: If the gRPC call fails
        """
        request = demo_pb2.EmptyCartRequest(user_id=user_id)
        logger.info(f"Calling EmptyCart(user_id={user_id})")
        response = self.stub.EmptyCart(request, timeout=self.timeout)
        logger.info("Cart emptied successfully")
        return response
