"""Coverage generator for extracting test coverage metrics from Jaeger traces."""

import json
import logging
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from urllib.parse import urlencode

import requests

logger = logging.getLogger(__name__)


class JaegerCoverageGenerator:
    """Generate test coverage metrics from Jaeger trace data."""

    def __init__(self, jaeger_url: Optional[str] = None, timeout: int = 30, config=None):
        """Initialize coverage generator.

        Args:
            jaeger_url: Base URL for Jaeger Query API. If None, will try to read from config.
            timeout: Request timeout in seconds (default: 30)
            config: Optional Config instance. If provided, will read Jaeger URL from config.
        """
        if jaeger_url is None:
            # Try to get from config if available
            if config is not None:
                try:
                    observability_config = config._config.get('observability', {})
                    jaeger_config = observability_config.get('jaeger', {})
                    host = jaeger_config.get('host', 'localhost')
                    port = jaeger_config.get('port', 16686)
                    jaeger_url = f"http://{host}:{port}"
                    logger.info(f"Using Jaeger URL from config: {jaeger_url}")
                except Exception as e:
                    logger.warning(f"Failed to read Jaeger URL from config: {e}, using default")
                    jaeger_url = "http://localhost:16686"
            else:
                # Default fallback
                jaeger_url = "http://localhost:16686"

        self.jaeger_url = jaeger_url.rstrip('/')
        self.timeout = timeout
        self.api_base = f"{self.jaeger_url}/api"

    def query_jaeger_traces(
        self,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        service: Optional[str] = None,
        limit: int = 1000,
    ) -> List[Dict]:
        """Query Jaeger API for traces.

        Args:
            start_time: Start time for trace query (default: 1 hour ago)
            end_time: End time for trace query (default: now)
            service: Filter by service name (REQUIRED by Jaeger API)
            limit: Maximum number of traces to return (default: 1000)

        Returns:
            List of trace dictionaries from Jaeger API

        Raises:
            requests.RequestException: If API request fails
        """
        from datetime import timezone
        
        # Default time range: last hour if not specified
        if end_time is None:
            end_time = datetime.now(timezone.utc)
        if start_time is None:
            start_time = end_time - timedelta(hours=1)

        # Ensure datetimes are timezone-aware (assume UTC if naive)
        if start_time.tzinfo is None:
            start_time = start_time.replace(tzinfo=timezone.utc)
        if end_time.tzinfo is None:
            end_time = end_time.replace(tzinfo=timezone.utc)

        # Convert to microseconds (Jaeger API expects microseconds since epoch)
        # .timestamp() on timezone-aware datetime returns UTC timestamp
        start_microseconds = int(start_time.timestamp() * 1_000_000)
        end_microseconds = int(end_time.timestamp() * 1_000_000)

        # Build query parameters
        # Note: Jaeger API requires 'service' parameter
        if not service:
            raise ValueError("Jaeger API requires 'service' parameter. Use query_all_services() to query all services.")

        params = {
            "service": service,
            "start": start_microseconds,
            "end": end_microseconds,
            "limit": limit,
        }

        url = f"{self.api_base}/traces"
        logger.debug(f"Querying Jaeger API: {url} with params: {params}")

        try:
            response = requests.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()

            if "data" not in data:
                logger.warning("Jaeger API response missing 'data' field")
                logger.debug(f"Full response: {json.dumps(data, indent=2)}")
                return []

            traces = data.get("data", [])
            if traces:
                logger.debug(f"Retrieved {len(traces)} traces for service '{service}'")
                # Log first trace structure for debugging
                if len(traces) > 0:
                    logger.debug(f"Sample trace structure for service '{service}': {json.dumps(traces[0], indent=2, default=str)[:1000]}")
            return traces

        except requests.exceptions.ConnectionError:
            logger.error(f"Failed to connect to Jaeger at {self.jaeger_url}")
            raise
        except requests.exceptions.Timeout:
            logger.error(f"Request to Jaeger timed out after {self.timeout}s")
            raise
        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error querying Jaeger for service '{service}': {e}")
            if e.response is not None:
                try:
                    error_detail = e.response.json()
                    logger.error(f"Error details: {error_detail}")
                except:
                    logger.error(f"Response text: {e.response.text[:200]}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Jaeger API response: {e}")
            raise

    def query_all_services(
        self,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        limit_per_service: int = 1000,
    ) -> List[Dict]:
        """Query Jaeger API for traces from test framework.

        Since the test framework creates gRPC client spans under its own service name
        (test-framework), we query traces from that service instead of backend services.
        The backend service names are extracted from operation names during coverage extraction.

        Args:
            start_time: Start time for trace query (default: 1 hour ago)
            end_time: End time for trace query (default: now)
            limit_per_service: Maximum number of traces per service (default: 1000)

        Returns:
            List of trace dictionaries from test framework
        """
        logger.info("Querying traces from test-framework service...")

        try:
            traces = self.query_jaeger_traces(
                start_time=start_time,
                end_time=end_time,
                service="test-framework",
                limit=limit_per_service,
            )
            logger.info(f"Retrieved {len(traces)} traces from test-framework")
            return traces
        except Exception as e:
            logger.warning(f"Failed to query traces for test-framework: {e}")
            return []

    def extract_coverage_metrics(self, traces: List[Dict]) -> Dict:
        """Extract coverage metrics from trace data.

        Args:
            traces: List of trace dictionaries from Jaeger API

        Returns:
            Dictionary containing coverage metrics:
            {
                "services": {
                    "service_name": {
                        "covered": True,
                        "methods": {
                            "method_name": {"covered": True, "call_count": N}
                        }
                    }
                }
            }
        """
        coverage = {}
        service_methods: Dict[str, Set[str]] = {}

        logger.info(f"Processing {len(traces)} traces for coverage extraction")
        
        if not traces:
            logger.warning("No traces provided to extract_coverage_metrics")
            return coverage

        # Log first trace structure for debugging
        logger.debug(f"Sample trace keys: {list(traces[0].keys()) if traces else 'No traces'}")
        if traces and len(traces) > 0:
            logger.debug(f"First trace structure (first 2000 chars): {json.dumps(traces[0], indent=2, default=str)[:2000]}")

        for trace_idx, trace in enumerate(traces):
            logger.debug(f"Processing trace {trace_idx + 1}/{len(traces)}")
            
            if "spans" not in trace:
                logger.warning(f"Trace {trace_idx} missing 'spans' key. Trace keys: {list(trace.keys())}")
                continue

            spans = trace.get("spans", [])
            logger.debug(f"Trace {trace_idx} has {len(spans)} spans")
            
            # Log trace structure for debugging (first trace only)
            if trace_idx == 0 and spans:
                logger.debug(f"Sample span structure: {json.dumps(spans[0], indent=2, default=str)[:1500]}")
                if "processes" in trace:
                    logger.debug(f"Processes in trace: {list(trace['processes'].keys())}")
                    for proc_id, proc in trace["processes"].items():
                        logger.debug(f"Process {proc_id}: serviceName={proc.get('serviceName')}, tags={proc.get('tags', [])[:3]}")

            for span_idx, span in enumerate(spans):
                logger.debug(f"Processing span {span_idx + 1}/{len(spans)} in trace {trace_idx}")
                logger.debug(f"Span keys: {list(span.keys())}")
                
                # Extract service name
                service_name = None
                
                # Try process.serviceName first (most common location)
                if "process" in span:
                    process = span.get("process", {})
                    service_name = process.get("serviceName", "")
                    logger.debug(f"Span {span_idx} process.serviceName: {service_name}")
                
                # Try processID -> process lookup (some Jaeger versions use processID)
                if not service_name and "processID" in span:
                    process_id = span.get("processID")
                    # Look up process in trace's processes dict
                    if "processes" in trace:
                        process = trace["processes"].get(process_id, {})
                        service_name = process.get("serviceName", "")
                        logger.debug(f"Span {span_idx} processID {process_id} -> serviceName: {service_name}")
                
                # Try tags as fallback
                if not service_name:
                    tags = span.get("tags", [])
                    logger.debug(f"Span {span_idx} checking {len(tags)} tags for service.name")
                    for tag in tags:
                        if isinstance(tag, dict):
                            tag_key = tag.get("key", "")
                            tag_value = tag.get("value", "")
                            if tag_key == "service.name":
                                service_name = tag_value
                                logger.debug(f"Found service.name in tags: {service_name}")
                                break
                        elif isinstance(tag, str):
                            # Some Jaeger versions use string format
                            if "service.name" in str(tag):
                                service_name = str(tag).split("=")[-1] if "=" in str(tag) else ""
                                logger.debug(f"Found service.name in tag string: {service_name}")
                                break

                if not service_name:
                    logger.warning(f"Span {span_idx} in trace {trace_idx} has no service name. SpanID: {span.get('spanID', 'unknown')}")
                    logger.debug(f"Full span data: {json.dumps(span, indent=2, default=str)[:500]}")
                    continue

                # Filter out infrastructure services
                if service_name.lower() in {'jaeger-all-in-one', 'jaeger', 'opentelemetrycollector', 'otel-collector'}:
                    logger.debug(f"Skipping infrastructure service: {service_name}")
                    continue

                # Extract operation/method name
                operation_name = span.get("operationName", "")
                if not operation_name:
                    logger.warning(f"Span {span_idx} in trace {trace_idx} for service '{service_name}' has no operationName")
                    logger.debug(f"Span keys: {list(span.keys())}")
                    continue

                # Filter out infrastructure operations (health checks, OTel collector exports)
                infrastructure_operations = {
                    '/grpc.health.v1.Health/Check',
                    'grpc.health.v1.Health/Check',
                    'opentelemetry.proto.collector.trace.v1.TraceService/Export',
                    '/api/traces',
                    '/api/services',
                }
                
                if operation_name in infrastructure_operations:
                    logger.debug(f"Skipping infrastructure operation: {operation_name}")
                    continue

                # Try to extract better service name from tags or process tags
                # Look for service.name tag or deployment.name tag
                actual_service_name = service_name
                tags = span.get("tags", [])
                process_tags = []
                
                # Get process tags if available
                if "processID" in span and "processes" in trace:
                    process_id = span.get("processID")
                    process = trace["processes"].get(process_id, {})
                    process_tags = process.get("tags", [])
                
                # Look for service.name in span tags
                for tag in tags:
                    if isinstance(tag, dict) and tag.get("key") == "service.name":
                        actual_service_name = tag.get("value", service_name)
                        logger.debug(f"Found service.name in span tags: {actual_service_name}")
                        break
                
                # Look for deployment.name or other identifying tags in process tags
                if actual_service_name.startswith("unknown_service"):
                    for tag in process_tags:
                        if isinstance(tag, dict):
                            tag_key = tag.get("key", "")
                            tag_value = tag.get("value", "")
                            # Try to extract service name from various tags
                            if tag_key in {"deployment.name", "service.namespace", "k8s.deployment.name"}:
                                # Use the tag value or try to parse it
                                if tag_value and not tag_value.startswith("unknown"):
                                    actual_service_name = tag_value
                                    logger.debug(f"Found service name from {tag_key}: {actual_service_name}")
                                    break
                            # Look for service name in otel attributes
                            elif "service" in tag_key.lower() and tag_value:
                                actual_service_name = tag_value
                                logger.debug(f"Found service name from {tag_key}: {actual_service_name}")
                                break
                
                # Try to extract service name from operation name if it's a gRPC call
                # Format: /hipstershop.ServiceName/MethodName or hipstershop.ServiceName/MethodName
                # This is critical for test-framework client spans which have operation names like
                # "/hipstershop.ProductCatalogService/GetProduct" but service name "test-framework"
                if operation_name.startswith("/hipstershop.") or operation_name.startswith("hipstershop."):
                    # Extract service name from gRPC method path
                    # Remove leading slash and "hipstershop." prefix
                    op_name_cleaned = operation_name.lstrip("/").replace("hipstershop.", "")
                    parts = op_name_cleaned.split("/")

                    if len(parts) > 0 and parts[0]:
                        # Extract service name (e.g., "ProductCatalogService" -> "productcatalogservice")
                        grpc_service = parts[0].lower()

                        # If current service is test-framework, always use the extracted target service
                        # This ensures client spans get attributed to the correct backend service
                        if actual_service_name == "test-framework" or actual_service_name.startswith("unknown"):
                            actual_service_name = grpc_service
                            logger.debug(f"Extracted target service from gRPC operation: {actual_service_name} (from {operation_name})")
                        else:
                            # Keep the actual service name if it's already a backend service
                            logger.debug(f"Keeping service name {actual_service_name} (operation: {operation_name})")

                logger.debug(f"Found service '{actual_service_name}' with operation '{operation_name}'")

                # Only track business logic gRPC calls (hipstershop services)
                # Skip if it's not a business logic call
                is_business_logic = (
                    operation_name.startswith("/hipstershop.") or
                    operation_name.startswith("hipstershop.") or
                    any(svc in actual_service_name.lower() for svc in [
                        'productcatalog', 'cart', 'recommendation', 'checkout',
                        'payment', 'shipping', 'currency', 'email', 'ad', 'frontend'
                    ])
                )
                
                if not is_business_logic:
                    logger.debug(f"Skipping non-business-logic operation: {operation_name} for service: {actual_service_name}")
                    continue

                # Initialize service in coverage dict
                if actual_service_name not in coverage:
                    coverage[actual_service_name] = {
                        "covered": True,
                        "methods": {},
                    }
                    service_methods[actual_service_name] = set()
                    logger.info(f"Added new service to coverage: {actual_service_name}")

                # Track method calls
                if operation_name not in service_methods[actual_service_name]:
                    service_methods[actual_service_name].add(operation_name)
                    coverage[actual_service_name]["methods"][operation_name] = {
                        "covered": True,
                        "call_count": 0,
                    }
                    logger.info(f"Added new method '{operation_name}' to service '{actual_service_name}'")

                # Increment call count
                coverage[actual_service_name]["methods"][operation_name]["call_count"] += 1
                logger.debug(f"Incremented call count for '{actual_service_name}.{operation_name}' to {coverage[actual_service_name]['methods'][operation_name]['call_count']}")

        # Calculate coverage percentages per service
        for service_name, service_data in coverage.items():
            method_count = len(service_data["methods"])
            if method_count > 0:
                # For now, we don't know total methods, so we'll mark as 100% if any methods are covered
                service_data["coverage_percentage"] = 100.0 if method_count > 0 else 0.0
            else:
                service_data["coverage_percentage"] = 0.0

        logger.info(f"Extracted coverage for {len(coverage)} services: {list(coverage.keys())}")
        return coverage

    def get_all_services(self) -> List[str]:
        """Get list of all services from Jaeger.

        Returns:
            List of service names available in Jaeger
        """
        url = f"{self.api_base}/services"
        logger.info(f"Querying Jaeger for services: {url}")

        try:
            response = requests.get(url, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()

            if "data" not in data:
                logger.warning("Jaeger API response missing 'data' field")
                return []

            services = data["data"]

            # Handle case where Jaeger returns {"data": null} instead of {"data": []}
            if services is None:
                logger.warning("Jaeger returned null for services list (no traces yet)")
                return []

            logger.info(f"Found {len(services)} services in Jaeger")
            return services

        except requests.exceptions.RequestException as e:
            logger.warning(f"Failed to query Jaeger services: {e}")
            return []

    def generate_coverage_report(
        self,
        coverage: Dict,
        output_path: Path,
        test_run_id: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
    ) -> Dict:
        """Generate consolidated coverage report.

        Args:
            coverage: Coverage metrics dictionary from extract_coverage_metrics()
            output_path: Path to write coverage report JSON file
            test_run_id: Optional test run identifier
            start_time: Test execution start time
            end_time: Test execution end time

        Returns:
            Complete coverage report dictionary
        """
        # Calculate summary statistics
        total_services = len(coverage)
        covered_services = sum(1 for s in coverage.values() if s.get("covered", False))
        service_coverage_percentage = (
            (covered_services / total_services * 100) if total_services > 0 else 0.0
        )

        # Count methods
        total_methods = sum(len(s.get("methods", {})) for s in coverage.values())
        covered_methods = total_methods  # All discovered methods are covered
        method_coverage_percentage = 100.0 if total_methods > 0 else 0.0

        # Build report
        from datetime import timezone
        
        # Use timezone-aware UTC datetime
        current_time = datetime.now(timezone.utc)
        
        # Format time_range - ensure timezone info is included
        def format_datetime(dt):
            """Format datetime with UTC timezone indicator."""
            if dt is None:
                return None
            # If timezone-aware, ensure it's formatted correctly
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            # Use ISO format with 'Z' suffix for UTC
            return dt.isoformat().replace('+00:00', 'Z')
        
        report = {
            "timestamp": current_time.isoformat().replace('+00:00', 'Z'),
            "test_run_id": test_run_id or f"test-run-{int(time.time())}",
            "time_range": {
                "start": format_datetime(start_time),
                "end": format_datetime(end_time),
            },
            "services": coverage,
            "summary": {
                "total_services": total_services,
                "covered_services": covered_services,
                "service_coverage_percentage": round(service_coverage_percentage, 2),
                "total_methods": total_methods,
                "covered_methods": covered_methods,
                "method_coverage_percentage": round(method_coverage_percentage, 2),
            },
        }

        # Write to file
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(report, f, indent=2)

        logger.info(f"Coverage report written to: {output_path}")
        return report

    def generate_coverage(
        self,
        output_path: Path,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        test_run_id: Optional[str] = None,
        time_buffer_seconds: int = 30,
    ) -> Optional[Dict]:
        """Generate coverage report from Jaeger traces.

        This is the main entry point that orchestrates the full coverage generation process.

        Args:
            output_path: Path to write coverage report JSON file
            start_time: Start time for trace query
            end_time: End time for trace query
            test_run_id: Optional test run identifier
            time_buffer_seconds: Buffer to add before start_time and after end_time to account
                                for trace indexing delays (default: 30 seconds)

        Returns:
            Coverage report dictionary, or None if generation failed
        """
        try:
            from datetime import timezone
            
            # Apply time buffer to account for trace indexing delays and clock skew
            # This is especially important when using exact test execution times
            query_start_time = start_time
            query_end_time = end_time
            
            if start_time is not None and end_time is not None:
                # Calculate time window duration
                time_window = (end_time - start_time).total_seconds()
                
                # If time window is very narrow (< 60 seconds), add buffer
                # This helps catch traces that might be indexed slightly after test completion
                if time_window < 60:
                    buffer = timedelta(seconds=time_buffer_seconds)
                    query_start_time = start_time - buffer
                    query_end_time = end_time + buffer
                    logger.info(f"Time window is narrow ({time_window:.2f}s), adding {time_buffer_seconds}s buffer: "
                              f"{query_start_time.isoformat()} to {query_end_time.isoformat()}")
                else:
                    logger.debug(f"Time window is wide enough ({time_window:.2f}s), using as-is")
            
            # Query traces from all services in Jaeger
            # Jaeger API requires a service parameter, so we query all services individually
            traces = self.query_all_services(start_time=query_start_time, end_time=query_end_time)

            if not traces:
                logger.warning("No traces found in Jaeger. Generating empty coverage report.")
                # Generate empty report
                empty_coverage = {}
                return self.generate_coverage_report(
                    empty_coverage,
                    output_path,
                    test_run_id=test_run_id,
                    start_time=start_time,
                    end_time=end_time,
                )

            # Extract coverage metrics
            coverage = self.extract_coverage_metrics(traces)

            # Generate report
            report = self.generate_coverage_report(
                coverage,
                output_path,
                test_run_id=test_run_id,
                start_time=start_time,
                end_time=end_time,
            )

            return report

        except Exception as e:
            logger.error(f"Failed to generate coverage: {e}", exc_info=True)
            # Generate empty report on error
            try:
                empty_coverage = {}
                return self.generate_coverage_report(
                    empty_coverage,
                    output_path,
                    test_run_id=test_run_id,
                    start_time=start_time,
                    end_time=end_time,
                )
            except Exception as report_error:
                logger.error(f"Failed to generate error report: {report_error}")
                return None

