# Axelar Node Kubernetes Deployment

This project provides Kubernetes manifests and tooling for deploying Axelar nodes and validators on Kubernetes clusters, following DevOps best practices.

## Overview

Axelar is a decentralized interoperability network that connects blockchain ecosystems. This deployment solution containerizes and orchestrates Axelar nodes using Kubernetes, providing:

- **Scalable Infrastructure**: Deploy multiple nodes with consistent configuration
- **High Availability**: Built-in health checks, restart policies, and monitoring
- **Security**: Proper secret management and network policies
- **Observability**: Prometheus metrics, logging, and monitoring dashboards
- **GitOps Ready**: CI/CD pipeline integration for automated deployments

## Architecture

### Node vs Validator Comparison

| Component | Node | Validator |
|-----------|------|-----------|
| **Purpose** | Sync blockchain state, serve RPC requests | Participate in consensus, sign blocks |
| **Requirements** | axelard binary, blockchain data | axelard + vald + tofnd binaries |
| **Key Management** | Node key only | Validator key + Tendermint consensus key + Tofnd key |
| **Network** | P2P connections to peers | P2P + validator-specific connections |
| **Resources** | Moderate CPU/Memory | Higher CPU/Memory requirements |
| **Staking** | No staking required | Must stake AXL tokens |
| **Responsibilities** | Data synchronization | Block validation and signing |

### Directory Structure

```
~/.axelar_testnet/          # Root directory for testnet
├── config/                 # Configuration files
│   ├── app.toml           # Application configuration
│   ├── config.toml        # Tendermint configuration
│   ├── genesis.json       # Genesis state
│   ├── node_key.json      # Node P2P identity
│   └── priv_validator_key.json  # Validator consensus key
├── data/                  # Blockchain data
│   ├── application.db     # Application state
│   ├── blockstore.db      # Block storage
│   ├── evidence.db        # Evidence database
│   ├── state.db          # Consensus state
│   └── tx_index.db       # Transaction index
├── keyring-file/          # Keyring storage
└── logs/                  # Log files
```

### Additional Validator Requirements

Validators require additional components beyond a basic node:

1. **vald**: Validator daemon for cross-chain operations
2. **tofnd**: Threshold signature daemon for multi-party computation
3. **Additional Keys**: 
   - Proxy/broadcaster key for transaction signing
   - Tofnd mnemonic for threshold signatures
4. **Higher Security**: Enhanced key management and backup procedures
5. **Monitoring**: Additional metrics for validator-specific operations

## Quick Start

### Prerequisites

- Kubernetes cluster (minikube for local testing)
- kubectl configured
- Helm 3.x (for Helm deployments)
- Docker (for building custom images)

### Option 1: Deploy with GitOps (ArgoCD) - Recommended for Production

```bash
# STEP 1: Configure repository URLs (REQUIRED)
./scripts/configure-gitops-repo.sh
# This auto-detects your repository URL and updates GitOps files

# STEP 2: Deploy ArgoCD with Axelar GitOps configuration
./scripts/deploy-argocd.sh

# STEP 3: Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (admin/admin123)

# Applications will auto-sync based on Git changes
# Manual sync for production environments
argocd app sync axelar-mainnet-validators
```

### Option 2: Deploy with Kubernetes Operator

```bash
# Deploy the operator
./scripts/deploy-operator.sh

# Deploy a testnet node using custom resource
kubectl apply -f operator/config/samples/testnet-observer.yaml

# Check node status
kubectl get axelarnode -o wide
```

### Option 3: Deploy with Helm

```bash
# Deploy a testnet node
./scripts/deploy-helm.sh -t node -n testnet -k your-secure-password

# Deploy a validator
./scripts/deploy-helm.sh -t validator -n testnet -k your-password -p your-tofnd-password

# Check deployment status
kubectl get pods -n axelar-testnet
```

### Option 4: Deploy with Kustomize

```bash
# Deploy to testnet
kubectl apply -f k8s/testnet/

# Check deployment status
kubectl get pods -n axelar-testnet

# View logs
kubectl logs -f deployment/axelar-node -n axelar-testnet
```

### Option 5: Deploy a Validator (Kustomize)

```bash
# Create secrets first
kubectl create secret generic axelar-validator-secrets \
  --from-literal=keyring-password=your-secure-password \
  --from-literal=tofnd-password=your-tofnd-password \
  -n axelar-testnet

# Deploy validator
kubectl apply -f k8s/validator/

# Monitor validator
kubectl logs -f deployment/axelar-validator -n axelar-testnet
```

## Project Structure

```
axelar-k8s-deployment/
├── README.md                    # This file
├── docs/                        # Documentation
│   ├── architecture.md          # Detailed architecture
│   ├── validator-setup.md       # Validator setup guide
│   ├── helm-deployment.md       # Helm deployment guide
│   ├── kubernetes-operator.md   # Kubernetes Operator guide
│   ├── gitops-argocd.md        # GitOps with ArgoCD guide
│   └── monitoring.md            # Monitoring setup
├── k8s/                         # Kubernetes manifests (Kustomize)
│   ├── base/                    # Base configurations
│   ├── testnet/                 # Testnet-specific configs
│   ├── mainnet/                 # Mainnet-specific configs
│   └── validator/               # Validator-specific configs
├── helm/                        # Helm charts
│   └── axelar-node/            # Axelar node Helm chart
│       ├── Chart.yaml          # Chart metadata
│       ├── values.yaml         # Default values
│       ├── values-*.yaml       # Environment-specific values
│       └── templates/          # Kubernetes templates
├── operator/                    # Kubernetes Operator
│   ├── cmd/                    # Operator main entry point
│   ├── pkg/                    # Operator source code
│   ├── config/                 # CRDs and samples
│   └── deploy/                 # Operator deployment manifests
├── gitops/                      # GitOps with ArgoCD
│   ├── argocd/                 # ArgoCD installation
│   ├── applications/           # ArgoCD Applications
│   ├── environments/           # Environment configurations
│   └── overlays/               # Shared overlays
├── docker/                      # Custom Docker images
├── scripts/                     # Utility scripts
│   ├── deploy.sh               # Kustomize deployment
│   ├── deploy-helm.sh          # Helm deployment
│   ├── deploy-operator.sh      # Operator deployment
│   ├── deploy-argocd.sh        # GitOps deployment
│   └── test-local.sh           # Local testing
├── monitoring/                  # Monitoring configurations
├── .github/workflows/           # CI/CD pipelines
└── tests/                       # Test configurations
```

## Features

- ✅ **Node Deployment**: Full node deployment with persistent storage
- ✅ **Validator Support**: Complete validator setup with all required components
- ✅ **Multi-Network**: Support for testnet and mainnet configurations
- ✅ **Kubernetes Operator**: Intelligent automation and lifecycle management
- ✅ **GitOps with ArgoCD**: Declarative, version-controlled deployments
- ✅ **Helm Charts**: Advanced templating and package management with Helm
- ✅ **Kustomize Support**: Overlay-based configuration management
- ✅ **Monitoring**: Prometheus metrics and Grafana dashboards
- ✅ **Security**: Proper secret management and network policies
- ✅ **CI/CD**: Automated testing and deployment pipelines
- ✅ **Local Testing**: Minikube-compatible configurations

## Monitoring

The deployment includes comprehensive monitoring:

- **Prometheus Metrics**: Node and validator metrics exposed on port 26660
- **Health Checks**: Kubernetes liveness and readiness probes
- **Log Aggregation**: Structured logging with log rotation
- **Alerting**: Critical alerts for node/validator issues

## Security Considerations

- Secrets are managed through Kubernetes secrets
- Network policies restrict unnecessary traffic
- Non-root containers with proper user permissions
- Regular security updates through CI/CD pipeline

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
