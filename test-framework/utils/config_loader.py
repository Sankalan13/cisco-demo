"""Configuration loader for test framework."""

import os
import yaml
from pathlib import Path


class Config:
    """Configuration management for test framework."""

    def __init__(self, config_path=None):
        """Initialize configuration.

        Args:
            config_path: Path to services.yaml config file.
                        If None, uses default location.
        """
        if config_path is None:
            # Default to config/services.yaml relative to project root
            project_root = Path(__file__).parent.parent
            config_path = project_root / "config" / "services.yaml"

        self.config_path = Path(config_path)
        self._config = self._load_config()

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
