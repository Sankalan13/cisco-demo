"""Configuration loader for test framework."""

import os
import yaml
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class Config:
    """Configuration management for test framework."""

    def __init__(self, config_path=None):
        """Initialize configuration.

        Args:
            config_path: Path to services.yaml config file.
                        If None, auto-detects based on TEST_MODE environment variable:
                        - TEST_MODE=kubernetes -> uses services-k8s.yaml
                        - TEST_MODE=local (default) -> uses services.yaml
        """
        if config_path is None:
            # Auto-detect configuration based on TEST_MODE environment variable
            test_mode = os.environ.get('TEST_MODE', 'local').lower()
            project_root = Path(__file__).parent.parent

            if test_mode == 'kubernetes':
                config_path = project_root / "config" / "services-k8s.yaml"
                logger.info("Running in KUBERNETES mode - using services-k8s.yaml")
            else:
                config_path = project_root / "config" / "services.yaml"
                logger.info("Running in LOCAL mode - using services.yaml")

        self.config_path = Path(config_path)
        self._config = self._load_config()
        logger.info(f"Configuration loaded from: {self.config_path}")

    def _load_config(self):
        """Load configuration from YAML file."""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Config file not found: {self.config_path}")

        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f)

    def get_service(self, service_name):
        """Get service configuration by name.

        Args:
            service_name: Name of the service (e.g., 'productcatalog', 'cart')

        Returns:
            dict: Service configuration containing host, port, etc.

        Raises:
            KeyError: If service name is not found in config.
        """
        if service_name not in self._config['services']:
            raise KeyError(f"Service '{service_name}' not found in configuration")

        return self._config['services'][service_name]

    def get_service_endpoint(self, service_name):
        """Get service endpoint (host:port) for gRPC connection.

        Args:
            service_name: Name of the service

        Returns:
            str: Endpoint in format 'host:port'
        """
        service = self.get_service(service_name)
        return f"{service['host']}:{service['port']}"

    def get_test_config(self, key=None):
        """Get test configuration.

        Args:
            key: Specific config key (e.g., 'timeout', 'retry_attempts')
                If None, returns entire test config dict.

        Returns:
            Test configuration value or dict.
        """
        test_config = self._config.get('test', {})
        if key is None:
            return test_config
        return test_config.get(key)

    def get_k8s_config(self, key=None):
        """Get Kubernetes configuration.

        Args:
            key: Specific config key (e.g., 'context', 'namespace')
                If None, returns entire k8s config dict.

        Returns:
            Kubernetes configuration value or dict.
        """
        k8s_config = self._config.get('kubernetes', {})
        if key is None:
            return k8s_config
        return k8s_config.get(key)


# Global config instance
_config_instance = None


def get_config():
    """Get global configuration instance (singleton pattern)."""
    global _config_instance
    if _config_instance is None:
        _config_instance = Config()
    return _config_instance
