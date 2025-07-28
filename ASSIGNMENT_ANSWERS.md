# Axelar SRE/DevOps Assignment - Answers

This document addresses the specific questions and requirements from the assignment.

## Assignment Overview

The assignment required:
1. **Write a Kubernetes manifest for deploying an Axelar node**
2. **Understand validator requirements and configuration**
3. **Answer specific questions about validators vs nodes**

## Task 1: Kubernetes Manifest for Axelar Node ✅

### Solution Provided

I've created a comprehensive Kubernetes deployment that includes:

- **Complete Kubernetes manifests** in `k8s/` directory
- **Production-ready configuration** with proper security contexts
- **Persistent storage** for blockchain data
- **ConfigMaps** for configuration management
- **Secrets** for sensitive data
- **Services** for network access
- **Health checks** and monitoring
- **Multi-environment support** (testnet/mainnet)

### Key Components

```
k8s/base/
├── namespace.yaml      # Kubernetes namespaces
├── configmap.yaml      # Axelar configuration (app.toml, config.toml)
├── pvc.yaml           # Persistent storage for blockchain data
├── service.yaml       # Network services (RPC, P2P, API, Prometheus)
├── deployment.yaml    # Main node deployment
└── secrets.yaml       # Secret management template
```

### Deployment Features

- **Security**: Non-root containers, dropped capabilities, security contexts
- **Storage**: 500GB persistent volumes for blockchain data
- **Networking**: Proper port exposure for RPC (26657), P2P (26656), API (1317)
- **Monitoring**: Prometheus metrics on port 26660
- **Health Checks**: Liveness and readiness probes
- **Resource Management**: CPU and memory limits/requests

### Testing with Minikube

The solution includes a complete testing script (`scripts/test-local.sh`) that:
- Starts minikube with appropriate resources
- Deploys the Axelar node
- Verifies all components are working
- Tests connectivity to RPC, API, and metrics endpoints

## Task 2: Validator Requirements and Configuration ✅

### A. Additional Requirements for Validator vs Node

Based on my analysis of the Axelar scripts and documentation:

| Aspect | Node | Validator |
|--------|------|-----------|
| **Purpose** | Sync blockchain state, serve RPC requests | Participate in consensus, validate blocks, sign transactions |
| **Components** | `axelard` binary only | `axelard` + `vald` + `tofnd` |
| **Key Management** | Node key for P2P identity | Multiple keys: Validator consensus key, Proxy/broadcaster key, Tofnd key, Node key |
| **Resources** | 2-4 CPU, 4-8GB RAM, 500GB storage | 4-8 CPU, 8-16GB RAM, 500GB+ storage |
| **Network** | P2P connections to peers | P2P + validator-specific connections |
| **Staking** | No staking required | Must stake AXL tokens to participate |
| **Security** | Standard node security | Enhanced security, key backup procedures |
| **Monitoring** | Basic node metrics | Enhanced validator-specific monitoring |
| **Responsibilities** | Data synchronization | Block validation, consensus participation, cross-chain operations |

### Additional Validator Components

1. **vald (Validator Daemon)**
   - Handles cross-chain operations
   - Manages validator-specific logic
   - Communicates with external chains

2. **tofnd (Threshold Signature Daemon)**
   - Implements multi-party computation (MPC)
   - Handles threshold signatures for security
   - Required for cross-chain transaction signing

### B. Directory Layout and File Purposes

Based on analysis of the Axelar scripts, here's the directory structure:

```
~/.axelar_testnet/                    # Root directory for testnet
├── config/                           # Configuration files
│   ├── app.toml                     # Application configuration
│   │   ├── minimum-gas-prices       # Gas price settings
│   │   ├── pruning settings         # State pruning configuration  
│   │   ├── API settings             # REST API configuration
│   │   ├── gRPC settings            # gRPC server configuration
│   │   └── telemetry settings       # Prometheus metrics
│   ├── config.toml                  # Tendermint configuration
│   │   ├── proxy_app                # ABCI application address
│   │   ├── moniker                  # Node name
│   │   ├── db_backend               # Database backend (goleveldb)
│   │   ├── RPC settings             # RPC server configuration
│   │   ├── P2P settings             # Peer-to-peer networking
│   │   ├── mempool settings         # Transaction pool
│   │   └── consensus settings       # Consensus parameters
│   ├── genesis.json                 # Network genesis state
│   ├── node_key.json               # Node P2P identity key
│   ├── priv_validator_key.json     # Validator consensus private key (CRITICAL)
│   └── addrbook.json               # Peer address book
├── data/                            # Blockchain data
│   ├── application.db              # Application state database
│   ├── blockstore.db               # Block storage database
│   ├── evidence.db                 # Evidence database
│   ├── state.db                    # Consensus state database
│   ├── tx_index.db                 # Transaction index database
│   ├── priv_validator_state.json   # Validator state (last signed)
│   └── cs.wal/                     # Consensus WAL files
├── keyring-file/                    # Keyring storage
│   └── [encrypted key files]       # Validator and proxy keys
└── logs/                           # Log files (if configured)
```

### File Purposes Explained

#### Critical Configuration Files
- **app.toml**: Controls application behavior (API endpoints, pruning, gas prices, telemetry)
- **config.toml**: Controls Tendermint consensus engine (P2P, RPC, consensus parameters)
- **genesis.json**: Initial blockchain state (validators, initial balances, chain parameters)

#### Critical Key Files
- **priv_validator_key.json**: **MOST CRITICAL** - Validator's private key for signing blocks
- **node_key.json**: Node's P2P identity for network communication
- **keyring-file/**: Encrypted storage for validator and proxy keys

#### Data Storage
- **application.db**: Current application state (balances, contracts, etc.)
- **blockstore.db**: Raw block data storage
- **state.db**: Consensus-related state information
- **priv_validator_state.json**: Prevents double-signing by tracking last signed height/round

## Additional Deliverables

Beyond the core requirements, I've provided:

### 1. High-Level Architecture Diagram
- Visual representation of the Kubernetes deployment
- Shows relationships between components
- Located at `diagrams/axelar-architecture-diagram.png`

### 2. Complete Validator Support
- Full validator deployment manifests in `k8s/validator/`
- Multi-container pod with axelard, vald, and tofnd
- Proper secret management for validator keys
- Enhanced security and monitoring

### 3. DevOps Best Practices
- **CI/CD Pipeline**: GitHub Actions workflow with testing and validation
- **Security Scanning**: Trivy vulnerability scanning
- **Monitoring**: Prometheus metrics and Grafana dashboards
- **Documentation**: Comprehensive guides and architecture documentation
- **Testing**: Automated testing with minikube
- **Scripts**: Deployment and testing automation

### 4. Production Readiness
- **Security**: Non-root containers, proper RBAC, secret management
- **Scalability**: Resource management, storage provisioning
- **Observability**: Metrics, logging, health checks
- **Reliability**: Proper restart policies, graceful shutdowns
- **Maintainability**: Clear documentation, automated deployments

## Prometheus Metrics Endpoint

The deployment exposes Prometheus metrics on port 26660 as required. Key metrics include:

- `tendermint_consensus_height`: Current block height
- `tendermint_p2p_peers`: Number of connected peers
- `process_resident_memory_bytes`: Memory usage
- `process_cpu_seconds_total`: CPU usage
- Custom Axelar-specific metrics

Access via:
```bash
kubectl port-forward svc/axelar-node-service 26660:26660 -n axelar-testnet
curl http://localhost:26660/metrics
```

## Testing and Validation

The solution includes comprehensive testing:

1. **Local Testing**: `scripts/test-local.sh` for minikube testing
2. **CI/CD Testing**: Automated testing in GitHub Actions
3. **Validation**: Kubernetes manifest validation
4. **Security**: Vulnerability scanning with Trivy

## Conclusion

This solution provides a production-ready, secure, and scalable way to deploy Axelar nodes and validators on Kubernetes. It follows DevOps best practices and includes comprehensive documentation, monitoring, and testing.

The key differentiators of this solution:

1. **Complete**: Covers both nodes and validators
2. **Production-Ready**: Includes security, monitoring, and CI/CD
3. **Well-Documented**: Comprehensive guides and architecture docs
4. **Tested**: Includes automated testing and validation
5. **Maintainable**: Clear structure and automation scripts

This demonstrates understanding of both Axelar-specific requirements and modern DevOps practices for Kubernetes deployments.
