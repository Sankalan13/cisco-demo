# System Tests for Google Microservices Demo

## Changes made to the source code

Here are some changes made to the source code to support coverage generation and some constraints yet to be addressed:

- Line coverage was only generated from golang services, first attempt was to add instrumentation to all services which failed
- Changes were made to the golang services to use a shared mod that can generate live coverage using a SIGUSR1 command without exiting or restarting the golang servers
- The dockerfiles for golang services were edited to support coverage profiling while the server is running, a total of 3 golang services were edited
- OpenCensus was available on the microservices apart from cart service, OpenTelemetry Collector was added to track system traces and generate behavioural coverage for the overall system. This coverage report shows us total number of API paths and services covered in the stack.
- Changes were made to the node services to fix a bug in trace generation, total 2 services were edited
- Cart Service was restarting duing tests because of low resource allocation, resource allocation was increased in the Kustomize manifests
- OpenTelemetryCollector and Jager were added to the service stack as observability to collect system wide traces and generate behavioural coverage
- Existing unit tests for each services was executed and the coverage reports can be found in the source folder

## Running the framework

NOTE: The below installation instructions are tested for macOS v15.6.1. In case of Linux, please install the same tools in your system before running the tests. The setup has also been tested in Ubuntu Server 24.04.2 LTS.
Ensure you have the following tools installed in your system:

- Install Homebrew if not available:
  
  ```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```
- Install pyenv to manage python versions, if you already have version 3.12.11 or an alternate tool to switch versions, skip ahead:

  ```brew install pyenv```
- Ensure pyenv is added to your PATH, for zsh users:

  ```echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zprofile```
  
  ```echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zprofile```
  
  ```echo 'eval "$(pyenv init -)"' >> ~/.zprofile```

  ```source ~/.zprofile```
- Install python dependencies if needed:

  ```brew install openssl readline sqlite3 xz zlib```
- Install the python version for the project (dictated via test-framework/.python-version file, to use a different version, update the content of this file after installation is complete):

  ```pyenv install 3.12.11```

  This should install the required python version in your system and switch to that version automatically. To verify if you are using the correct version, run:

  ```python -V```

  If you see 3.12.11 as output, move ahead, else run:

  ```pyenv local 3.12.11```
  
  You should now have the correct version set, you can verify with the aforementioned command.
- Install Docker for Desktop from the official website if not already available:

  ```https://docs.docker.com/desktop/setup/install/mac-install/```

  The office google images for the services are not publicly available in docker registry (```us-central1-docker.pkg.dev/google-samples/microservices-demo/adservice:v0.10.3```) so ensure that you login to docker by running the below command and following the instructions to authenticate. This is a constraint on how docker images are saved by google.

  ```docker login```
- Install kubectl

  ```https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/```
- Install kind

  ```brew install kind```
- Verify if netcat is installed in your mac by running:

  ```nc -h```

  If it is not installed, install it using homebrew:

  ```brew install netcat```

- Once everything is installed, you should be able to run the tests from the root directory using the below command:

  ```make full-ci```

  This command does the following:
  - Builds custom service images locally
    - Builds Node.js services with OpenTelemetry fixes:
      - currencyservice:local-fixed
      - paymentservice:local-fixed
    - Builds Go services with coverage instrumentation:
      - productcatalogservice:local-coverage
      - checkoutservice:local-coverage
      - shippingservice:local-coverage
  - Creates and verifies Kind cluster
  - Loads images into the cluster
  - Deploys services and observability with Kustomize
  - Starts port-forwarding for local access
  - Runs tests
  - Generates coverage metrics

## Quick Start Commands

```bash
# Full workflow (build, deploy, test, coverage)
make all

# Fast iteration (skip builds if cached)
make quick

# Show all available commands
make help

# Build only
make build

# Deploy only
make deploy

# Run tests only
make test

# Generate coverage
make coverage

# Clean up everything
make clean-all
```

For detailed command reference, see [docs/MAKEFILE_REFERENCE.md](docs/MAKEFILE_REFERENCE.md).

## Documentation

Comprehensive documentation is available in the [docs/](docs/) directory:

- **[Documentation Index](docs/README.md)** - Complete documentation overview and navigation
- **[Test Framework Guide](docs/TEST_FRAMEWORK.md)** - BDD test framework documentation
- **[Makefile Reference](docs/MAKEFILE_REFERENCE.md)** - All available Make targets
- **[Go Coverage Guide](docs/GO_COVERAGE_GUIDE.md)** - Code-level coverage for Go services
- **[Tracing and Observability](docs/TRACING_AND_OBSERVABILITY.md)** - OpenTelemetry/Jaeger setup
- **[K8s Test Deployment](docs/K8S_TEST_DEPLOYMENT.md)** - Running tests in Kubernetes
- **[Microservices Demo](docs/MICROSERVICES_DEMO.md)** - Original Google Cloud demo docs

## Artifacts Generated

Test Reports: ```test-framework/reports/*.xml (JUnit format)```
Trace Coverage: ```test-framework/reports/coverage.json```
Go Coverage: ```test-framework/reports/go-coverage-*.html```
Test Timing: ```test-framework/reports/test_execution_time.json```

## Observability Access

Jaeger UI: ```http://localhost:16686```
Service Endpoints: Various localhost ports (3550, 7070, etc.)

## Other Constraints

- Due to lack of a paid LLM subscription, it was difficult working with free available versions. A monthly subscription for Claude was purchased for $23.60.
- Claude Pro Plan includes a 5 hour session time lock with model usage constraints that made development slow and inconsistent

## What I learnt

- Good LLM support agents are expensive
- Instrumenting a dotnet service is not as easy as its put out to be
- Makefile is great at a lot of things over shell script but shell is still great at fine grain user control to the workflow

## Further improvements

Provided with the $100 Claude Max subscription, further improvements would have been made to the current framework. The pro version model usage cap was reached within 3 days of development work and buying the Max subscription was not possible. Maxed out all my free usage on tools like Cursor and Windsurf for multiple accounts. The project was built from Friday to Sunday. With the initial plan to submit the assignment on Wednesday, I would have changed:

- Add helm chart deployments and helmfile with test job as helm test hook using helmfile, currently using Kustomize for deployments
- Added unit tests and collected unit tests coverage since not all services has unit tests
- Added contract tests between the consumers and producers in the microservice architecture
- Added UI tests for critical priority happy case user lifecycle flows
- Improved test data management
- Improved line coverage for golang services
  
