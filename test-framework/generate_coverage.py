#!/usr/bin/env python3
"""Standalone script to generate test coverage from Jaeger traces.

Usage:
    python3 generate_coverage.py [--start-time TIMESTAMP] [--end-time TIMESTAMP] [--output PATH] [--jaeger-url URL]

Examples:
    # Generate coverage for last hour
    python3 generate_coverage.py

    # Generate coverage for specific time range
    python3 generate_coverage.py --start-time "2024-01-15T10:00:00" --end-time "2024-01-15T11:00:00"

    # Specify custom output path
    python3 generate_coverage.py --output reports/custom_coverage.json
"""

import argparse
import logging
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from utils.coverage_generator import JaegerCoverageGenerator
from utils.config_loader import get_config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def parse_datetime(time_str: str) -> datetime:
    """Parse datetime string in ISO format.

    Args:
        time_str: ISO format datetime string (e.g., "2024-01-15T10:00:00Z" or "2024-01-15T10:00:00")

    Returns:
        timezone-aware datetime object (UTC if no timezone specified)

    Raises:
        ValueError: If time string cannot be parsed
    """
    try:
        from datetime import timezone
        
        # Try parsing with timezone
        if 'Z' in time_str:
            # Convert Z to +00:00 for UTC
            return datetime.fromisoformat(time_str.replace('Z', '+00:00'))
        elif '+' in time_str or (time_str.count('-') > 2 and ':' in time_str[-6:]):
            # Has explicit timezone offset
            return datetime.fromisoformat(time_str)
        else:
            # No timezone specified - assume UTC and make timezone-aware
            naive_dt = datetime.fromisoformat(time_str)
            return naive_dt.replace(tzinfo=timezone.utc)
    except ValueError as e:
        raise ValueError(f"Invalid datetime format: {time_str}. Use ISO format (e.g., '2024-01-15T10:00:00Z')") from e


def main():
    """Main entry point for coverage generation script."""
    parser = argparse.ArgumentParser(
        description="Generate test coverage metrics from Jaeger traces",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        "--start-time",
        type=str,
        help="Start time for trace query (ISO format, e.g., '2024-01-15T10:00:00'). Default: 1 hour ago"
    )

    parser.add_argument(
        "--end-time",
        type=str,
        help="End time for trace query (ISO format, e.g., '2024-01-15T11:00:00'). Default: now"
    )

    parser.add_argument(
        "--output",
        type=str,
        default="reports/coverage.json",
        help="Output path for coverage report (default: reports/coverage.json)"
    )

    parser.add_argument(
        "--jaeger-url",
        type=str,
        default=None,
        help="Jaeger Query API URL (default: read from services.yaml config, fallback: http://localhost:16686)"
    )

    parser.add_argument(
        "--test-run-id",
        type=str,
        help="Test run identifier (default: auto-generated)"
    )

    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose logging"
    )

    parser.add_argument(
        "--time-buffer",
        type=int,
        default=30,
        help="Time buffer in seconds to add before start and after end time (default: 30). "
             "Helps catch traces that may be indexed slightly after test completion."
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Parse time arguments
    # Use timezone-aware UTC datetime as default
    end_time = datetime.now(timezone.utc)
    if args.end_time:
        try:
            end_time = parse_datetime(args.end_time)
        except ValueError as e:
            logger.error(f"Invalid end-time: {e}")
            sys.exit(1)

    start_time = end_time - timedelta(hours=1)
    if args.start_time:
        try:
            start_time = parse_datetime(args.start_time)
        except ValueError as e:
            logger.error(f"Invalid start-time: {e}")
            sys.exit(1)

    # Validate time range
    if start_time >= end_time:
        logger.error("Start time must be before end time")
        sys.exit(1)

    # Resolve output path
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = project_root / output_path

    logger.info("=" * 60)
    logger.info("Jaeger Test Coverage Generation")
    logger.info("=" * 60)
    
    # Initialize coverage generator
    try:
        # Use config if jaeger-url not explicitly provided
        config = None
        if args.jaeger_url is None:
            try:
                config = get_config()
                logger.info("Using Jaeger configuration from services.yaml")
            except Exception as e:
                logger.debug(f"Could not load config: {e}, using defaults")

        generator = JaegerCoverageGenerator(jaeger_url=args.jaeger_url, config=config)
        
        # Log the actual URL being used
        logger.info(f"Jaeger URL: {generator.jaeger_url}")
    except Exception as e:
        logger.error(f"Failed to initialize coverage generator: {e}")
        sys.exit(1)
    
    logger.info(f"Time range: {start_time.isoformat()} to {end_time.isoformat()}")
    logger.info(f"Output path: {output_path}")
    logger.info("")

    # Generate coverage
    try:
        report = generator.generate_coverage(
            output_path=output_path,
            start_time=start_time,
            end_time=end_time,
            test_run_id=args.test_run_id,
            time_buffer_seconds=args.time_buffer,
        )

        if report is None:
            logger.error("Coverage generation failed")
            sys.exit(1)

        # Print summary
        summary = report.get("summary", {})
        logger.info("")
        logger.info("=" * 60)
        logger.info("Coverage Summary")
        logger.info("=" * 60)
        logger.info(f"Total Services: {summary.get('total_services', 0)}")
        logger.info(f"Covered Services: {summary.get('covered_services', 0)}")
        logger.info(f"Service Coverage: {summary.get('service_coverage_percentage', 0.0)}%")
        logger.info(f"Total Methods: {summary.get('total_methods', 0)}")
        logger.info(f"Covered Methods: {summary.get('covered_methods', 0)}")
        logger.info(f"Method Coverage: {summary.get('method_coverage_percentage', 0.0)}%")
        logger.info("")
        logger.info(f"Coverage report saved to: {output_path}")
        logger.info("=" * 60)

        sys.exit(0)

    except KeyboardInterrupt:
        logger.warning("Coverage generation interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unexpected error during coverage generation: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

