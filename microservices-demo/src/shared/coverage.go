// Package shared provides common utilities for microservices
package shared

import (
	"log"
	"os"
	"os/signal"
	"runtime/coverage"
	"syscall"
)

// SetupCoverageSignalHandler enables on-demand coverage dumping via SIGUSR1 signal.
// This allows collecting Go code coverage from running services without shutting them down.
//
// When GOCOVERDIR environment variable is set, this function registers a signal handler
// that listens for SIGUSR1. On receiving the signal, it writes coverage data to the
// directory specified by GOCOVERDIR and clears the counters for the next collection.
//
// This is particularly useful for integration testing scenarios where:
//   - Services need to keep running after tests complete
//   - Coverage needs to be collected at specific points in time
//   - Multiple test runs should produce separate coverage data
//
// Usage:
//
//	func main() {
//	    shared.SetupCoverageSignalHandler()  // Call as first line in main()
//	    // ... rest of your service initialization
//	}
//
// To trigger coverage dump from outside the process:
//
//	kubectl exec <pod-name> -- kill -SIGUSR1 1
//
// Note: This function is a no-op if GOCOVERDIR is not set, allowing the same
// binary to run with or without coverage collection based on environment config.
func SetupCoverageSignalHandler() {
	coverDir, exists := os.LookupEnv("GOCOVERDIR")
	if !exists {
		// Coverage not enabled, skip handler setup
		return
	}

	// Create signal channel for SIGUSR1
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGUSR1)

	// Start goroutine to handle coverage dump signals
	go func() {
		for {
			<-c
			log.Println("Coverage: Received SIGUSR1 signal, dumping coverage data...")

			// Write coverage counters to GOCOVERDIR
			if err := coverage.WriteCountersDir(coverDir); err != nil {
				log.Printf("Coverage: Error writing coverage data: %v", err)
			} else {
				log.Println("Coverage: Successfully wrote coverage data")
			}

			// Clear counters for next collection period
			// This allows tracking coverage for each test run separately
			if err := coverage.ClearCounters(); err != nil {
				log.Printf("Coverage: Error clearing counters: %v", err)
			} else {
				log.Println("Coverage: Counters cleared for next collection")
			}
		}
	}()

	log.Printf("Coverage: Signal handler registered (GOCOVERDIR=%s)", coverDir)
	log.Println("Coverage: Send SIGUSR1 to dump coverage without stopping the service")
}
