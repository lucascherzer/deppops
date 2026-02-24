# Deppops

A simple Rust web service built with Actix-Web for DevOps demonstration purposes.

## Features

- Simple HTTP server with health check endpoints
- Structured logging with `tracing`
- Kubernetes-ready with proper health probes
- Container build with Nix
- Automated CI/CD pipeline with GitHub Actions
- ArgoCD integration for continuous deployment

## Endpoints

### Main Endpoint

- **GET `/`** - Returns "Hello!" message
  - Response: `200 OK` with plain text body

### Health Check Endpoints

- **GET `/health/live`** - Liveness probe endpoint
  - Returns: `{"status": "alive"}`
  - Used by Kubernetes to determine if the container should be restarted

- **GET `/health/ready`** - Readiness probe endpoint
  - Returns: `{"status": "ready"}`
  - Used by Kubernetes to determine if the pod can receive traffic

## Development

### Prerequisites

- Nix with flakes enabled
- Rust (or use the Nix dev shell)

### Running Locally

Using Nix:
```bash
nix run
```

Or with cargo:
```bash
cargo run
```

The server will start on `http://127.0.0.1:8080`.

### Testing

Run all tests:
```bash
nix flake check
```

Or with cargo:
```bash
cargo test
```

### Environment Variables

- `RUST_LOG` - Set log level (default: `deppops=debug,actix_web=info`)
  - Example: `RUST_LOG=debug cargo run`
  - Example: `RUST_LOG=trace cargo run` (to see health check logs)

## Container Build

Build the container image using Nix:
```bash
nix build .#container
```

The image is built with `dockerTools.buildImage` and tagged with the git short revision.

## Kubernetes Deployment

The application is deployed to Kubernetes using manifests in the `k8s/` directory:

- `namespace.yaml` - Creates the `deppops` namespace
- `deployment.yaml` - Deploys 2 replicas with health checks
- `service.yaml` - Exposes the application internally
- `ingress.yaml` - Configures external access

### Resource Requirements

- CPU: 100m request, 200m limit
- Memory: 64Mi request, 128Mi limit

## CI/CD

### Quality Checks (`quality.yml`)

Runs on every push and pull request:
- Nix build
- Unit tests
- Clippy linting
- Format checking
- Security audit with cargo-audit
- SAST scanning with semgrep
- Kubernetes manifest validation with kubeconform

### Release Pipeline (`release.yml`)

Runs on push to `main`:
1. Builds container image with Nix
2. Generates SBOM and vulnerability reports with Syft and Grype
3. Pushes to GitHub Container Registry
4. Attaches SBOM as attestation
5. Signs container with Cosign

### ArgoCD

The repository is connected to ArgoCD with auto-sync enabled. When changes are pushed to the `k8s/` directory, ArgoCD automatically deploys them to the cluster.

## Post Build
After each build, a new container is published on ghcr.io.

You can view its SBOM like using a provided script:
```sh
nu scripts/get-sbom 'gchr.io/<oci-path>.sbom'
# see `nu scripts/get-sbom.nu --help` for more options
```
Alternatively, you can also do it manually:
```sh
skopeo copy docker://ghcr.io/lucascherzer/deppops/deppops:sha256-1f0799e6f9705324be6c2fc94ced25c983a162289849cee1702fc01b5530bb8b.sbom dir:./sbom:latest
```
This creates a directory named `sbom:latest`. It contains two files with a long hash for a name. One of them is the SBOM.

## Observability

The application uses structured logging with `tracing`:

- **Application endpoints** (`/`): Logged at `INFO` level
- **Health check endpoints** (`/health/*`): Logged at `TRACE` level

This prevents Kubernetes health probes (which run every 5-10 seconds) from flooding the logs. To see health check logs during development, set `RUST_LOG=trace`.

## License

MIT
