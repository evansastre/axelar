# Getting Started with Axelar Kubernetes Deployment

## Quick Start

This project provides production-ready Kubernetes manifests for deploying Axelar nodes and validators. Follow these steps to get started quickly.

### Prerequisites

- Kubernetes cluster (minikube for local testing)
- kubectl configured
- Basic understanding of Kubernetes concepts

### 1. Local Testing with Minikube

```bash
# Clone the repository
git clone <repository-url>
cd axelar-k8s-deployment

# Start local testing
./scripts/test-local.sh
```

This script will:
- Start minikube with appropriate resources
- Deploy an Axelar testnet node
- Verify the deployment is working
- Show you how to access the services

### 2. Deploy to Existing Cluster

```bash
# Deploy a node
./scripts/deploy.sh -n testnet -c node -k your-secure-password

# Deploy a validator (requires additional setup)
./scripts/deploy.sh -n testnet -c validator -k your-secure-password -t your-tofnd-password
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -n axelar-testnet

# View logs
kubectl logs -f deployment/axelar-node -n axelar-testnet

# Access services
kubectl port-forward svc/axelar-node-service 26657:26657 -n axelar-testnet
curl http://localhost:26657/status
```

## Project Structure

```
axelar-k8s-deployment/
├── README.md                    # Project overview
├── GETTING_STARTED.md          # This file
├── docs/                       # Detailed documentation
│   ├── architecture.md         # Architecture overview
│   ├── validator-setup.md      # Validator setup guide
│   └── monitoring.md           # Monitoring setup
├── k8s/                        # Kubernetes manifests
│   ├── base/                   # Base configurations
│   │   ├── namespace.yaml      # Namespaces
│   │   ├── configmap.yaml      # Configuration
│   │   ├── pvc.yaml           # Storage
│   │   ├── service.yaml       # Services
│   │   ├── deployment.yaml    # Node deployment
│   │   └── secrets.yaml       # Secrets template
│   ├── testnet/               # Testnet-specific configs
│   │   ├── kustomization.yaml # Kustomize config
│   │   └── deployment-patch.yaml
│   └── validator/             # Validator-specific configs
│       ├── validator-deployment.yaml
│       ├── validator-pvc.yaml
│       └── validator-secrets.yaml
├── scripts/                   # Utility scripts
│   ├── deploy.sh             # Deployment script
│   └── test-local.sh         # Local testing script
├── monitoring/               # Monitoring configurations
│   ├── servicemonitor.yaml  # Prometheus monitoring
│   └── grafana-dashboard.json
├── tests/                   # Test configurations
│   └── test-config.yaml    # Test jobs
└── .github/workflows/      # CI/CD pipeline
    └── ci.yml             # GitHub Actions
```

## Key Features

✅ **Production Ready**: Follows Kubernetes best practices
✅ **Security First**: Non-root containers, secret management
✅ **Monitoring**: Prometheus metrics and Grafana dashboards
✅ **Multi-Environment**: Support for testnet and mainnet
✅ **Validator Support**: Complete validator deployment with vald and tofnd
✅ **CI/CD Pipeline**: Automated testing and deployment
✅ **Documentation**: Comprehensive guides and architecture docs

## Understanding Axelar Components

### Node vs Validator

| Aspect | Node | Validator |
|--------|------|-----------|
| **Purpose** | Sync blockchain, serve RPC | Participate in consensus |
| **Components** | axelard only | axelard + vald + tofnd |
| **Keys** | Node key | Validator + Tendermint + Tofnd keys |
| **Resources** | 2-4 CPU, 4-8GB RAM | 4-8 CPU, 8-16GB RAM |
| **Staking** | Not required | Must stake AXL tokens |

### Directory Layout

The Axelar node uses this directory structure:

```
~/.axelar_testnet/
├── config/                 # Configuration files
│   ├── app.toml           # Application settings
│   ├── config.toml        # Tendermint settings
│   ├── genesis.json       # Network genesis
│   ├── node_key.json      # P2P identity
│   └── priv_validator_key.json  # Validator key
├── data/                  # Blockchain data
│   ├── application.db     # App state
│   ├── blockstore.db      # Blocks
│   └── state.db          # Consensus state
└── keyring-file/          # Key storage
```

## Next Steps

### For Node Operators

1. **Deploy a Node**: Start with the local testing script
2. **Monitor**: Set up Prometheus and Grafana monitoring
3. **Backup**: Implement backup procedures for important data
4. **Scale**: Consider resource requirements for your use case

### For Validator Operators

1. **Understand Requirements**: Read the validator setup guide
2. **Security Setup**: Implement proper key management
3. **Deploy Validator**: Follow the validator deployment process
4. **Register**: Register your validator on the network
5. **Monitor**: Set up comprehensive monitoring and alerting

### For DevOps Engineers

1. **CI/CD Integration**: Integrate with your existing CI/CD pipeline
2. **GitOps**: Consider ArgoCD or Flux for GitOps workflows
3. **Service Mesh**: Integrate with Istio or Linkerd if needed
4. **Multi-cluster**: Extend for multi-cluster deployments

## Common Tasks

### View Logs
```bash
kubectl logs -f deployment/axelar-node -n axelar-testnet
```

### Access RPC
```bash
kubectl port-forward svc/axelar-node-service 26657:26657 -n axelar-testnet
curl http://localhost:26657/status
```

### Check Metrics
```bash
kubectl port-forward svc/axelar-node-service 26660:26660 -n axelar-testnet
curl http://localhost:26660/metrics
```

### Scale Resources
```bash
kubectl patch deployment axelar-node -n axelar-testnet -p '{"spec":{"template":{"spec":{"containers":[{"name":"axelar-node","resources":{"requests":{"cpu":"4","memory":"8Gi"}}}]}}}}'
```

### Update Configuration
```bash
kubectl edit configmap axelar-config -n axelar-testnet
kubectl rollout restart deployment/axelar-node -n axelar-testnet
```

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n axelar-testnet
kubectl logs <pod-name> -n axelar-testnet
```

### Storage Issues
```bash
kubectl get pvc -n axelar-testnet
kubectl describe pvc axelar-node-data -n axelar-testnet
```

### Network Issues
```bash
kubectl get svc -n axelar-testnet
kubectl describe svc axelar-node-service -n axelar-testnet
```

### Configuration Issues
```bash
kubectl get configmap axelar-config -n axelar-testnet -o yaml
```

## Support and Contributing

- **Documentation**: Check the `docs/` directory for detailed guides
- **Issues**: Report issues via GitHub issues
- **Contributing**: Submit pull requests with improvements
- **Community**: Join the Axelar community for support

## Security Considerations

- **Secrets**: Never commit secrets to version control
- **Keys**: Backup validator keys securely
- **Access**: Limit access to production deployments
- **Updates**: Keep images and configurations updated
- **Monitoring**: Monitor for security events

## Performance Tips

- **Storage**: Use SSD storage for better performance
- **Network**: Ensure good network connectivity
- **Resources**: Monitor and adjust resource limits
- **Pruning**: Configure state pruning appropriately
- **Peers**: Maintain good peer connections

## What's Next?

This deployment provides a solid foundation for running Axelar nodes and validators on Kubernetes. Consider these enhancements:

1. **Helm Charts**: Package as Helm charts for easier management
2. **Operators**: Develop Kubernetes operators for automated operations
3. **Multi-region**: Deploy across multiple regions for redundancy
4. **Advanced Monitoring**: Implement SLI/SLO monitoring
5. **Disaster Recovery**: Implement comprehensive DR procedures

Happy deploying! 🚀
