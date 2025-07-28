# Axelar Validator Setup Guide

## Overview

This guide provides detailed instructions for setting up an Axelar validator on Kubernetes. A validator is a special type of node that participates in the consensus mechanism and helps secure the network.

## Prerequisites

- Kubernetes cluster with sufficient resources
- kubectl configured and working
- Understanding of Axelar network concepts
- Secure key management practices

## Validator vs Node Comparison

### Node Requirements
- **Purpose**: Sync blockchain state, serve RPC requests
- **Components**: axelard binary only
- **Keys**: Node key for P2P identity
- **Resources**: 2-4 CPU, 4-8GB RAM, 500GB storage
- **Network**: P2P connections to peers
- **Staking**: No staking required

### Validator Requirements
- **Purpose**: Participate in consensus, validate blocks, sign transactions
- **Components**: axelard + vald + tofnd
- **Keys**: 
  - Validator consensus key (Tendermint)
  - Proxy/broadcaster key (for transactions)
  - Tofnd key (for threshold signatures)
  - Node key (for P2P)
- **Resources**: 4-8 CPU, 8-16GB RAM, 500GB+ storage
- **Network**: P2P + validator-specific connections
- **Staking**: Must stake AXL tokens to participate

## Directory Structure Analysis

Based on the Axelar scripts analysis, here's the directory layout and purpose:

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
│   │   ├── db_backend               # Database backend
│   │   ├── RPC settings             # RPC server configuration
│   │   ├── P2P settings             # Peer-to-peer networking
│   │   ├── mempool settings         # Transaction pool
│   │   └── consensus settings       # Consensus parameters
│   ├── genesis.json                 # Network genesis state
│   ├── node_key.json               # Node P2P identity key
│   ├── priv_validator_key.json     # Validator consensus private key
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

### Key Files Explained

#### Configuration Files
- **app.toml**: Controls application-level settings like API endpoints, pruning, and telemetry
- **config.toml**: Controls Tendermint consensus engine settings, P2P networking, and RPC
- **genesis.json**: Contains the initial state of the blockchain network

#### Key Files
- **priv_validator_key.json**: **CRITICAL** - Validator's consensus private key for signing blocks
- **node_key.json**: Node's P2P identity key for network communication
- **keyring-file/**: Contains encrypted validator and proxy keys managed by Cosmos keyring

#### Data Files
- **application.db**: Stores the current application state (balances, smart contracts, etc.)
- **blockstore.db**: Stores raw block data
- **state.db**: Stores consensus-related state information
- **priv_validator_state.json**: Tracks the last height/round signed to prevent double-signing

## Validator Setup Process

### Step 1: Prepare Validator Keys

Before deploying, you need to generate or obtain validator keys:

```bash
# Generate validator mnemonic (if creating new validator)
axelard keys add validator --keyring-backend file

# Generate tofnd mnemonic (for threshold signatures)
tofnd -m generate > tofnd_mnemonic.txt

# Export validator address
axelard keys show validator --keyring-backend file --address > validator.bech
```

### Step 2: Create Kubernetes Secrets

```bash
# Create validator secrets with all required keys
kubectl create secret generic axelar-validator-secrets \
  --from-literal=keyring-password=your-secure-password \
  --from-literal=tofnd-password=your-tofnd-password \
  --from-file=validator-mnemonic=./validator_mnemonic.txt \
  --from-file=tofnd-mnemonic=./tofnd_mnemonic.txt \
  --from-file=tendermint-key=./priv_validator_key.json \
  -n axelar-testnet
```

### Step 3: Deploy Validator

```bash
# Deploy validator components
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/validator/

# Wait for deployment
kubectl wait --for=condition=available --timeout=600s deployment/axelar-validator -n axelar-testnet
```

### Step 4: Verify Deployment

```bash
# Check all containers are running
kubectl get pods -n axelar-testnet -l app.kubernetes.io/component=validator

# Check logs for each container
kubectl logs deployment/axelar-validator -c axelar-validator -n axelar-testnet
kubectl logs deployment/axelar-validator -c vald -n axelar-testnet
kubectl logs deployment/axelar-validator -c tofnd -n axelar-testnet
```

### Step 5: Register Validator (Testnet)

```bash
# Port forward to access the node
kubectl port-forward svc/axelar-validator-service 26657:26657 -n axelar-testnet &

# Create validator transaction
axelard tx staking create-validator \
  --amount=1000000uaxl \
  --pubkey=$(axelard tendermint show-validator) \
  --moniker="my-validator" \
  --chain-id=axelar-testnet-lisbon-3 \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1000000" \
  --gas="auto" \
  --gas-prices="0.007uaxl" \
  --from=validator \
  --keyring-backend=file \
  --node=http://localhost:26657
```

## Additional Validator Requirements

### 1. Enhanced Security

Validators require additional security measures:

```yaml
# Enhanced security context
securityContext:
  runAsUser: 1000
  runAsGroup: 1001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# Network policies (example)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: validator-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: validator
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: monitoring
    ports:
    - protocol: TCP
      port: 26660
  egress:
  - {} # Allow all egress for P2P
```

### 2. Key Management

Critical key management practices:

```bash
# Backup critical files
BACKUP_DIR="validator-backup-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Copy critical files
cp ~/.axelar_testnet/config/priv_validator_key.json $BACKUP_DIR/
cp ~/.axelar_testnet/config/node_key.json $BACKUP_DIR/
cp validator_mnemonic.txt $BACKUP_DIR/
cp tofnd_mnemonic.txt $BACKUP_DIR/

# Encrypt and store securely
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR/
gpg --symmetric --cipher-algo AES256 $BACKUP_DIR.tar.gz
```

### 3. Monitoring and Alerting

Enhanced monitoring for validators:

```yaml
# Validator-specific alerts
groups:
- name: axelar-validator
  rules:
  - alert: ValidatorDown
    expr: up{job="axelar-validator"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Axelar validator is down"
      
  - alert: ValidatorMissedBlocks
    expr: increase(tendermint_consensus_validator_missed_blocks[5m]) > 5
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Validator missing blocks"
      
  - alert: ValidatorNotSigning
    expr: increase(tendermint_consensus_validator_last_signed_height[10m]) == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Validator not signing blocks"
```

### 4. Resource Requirements

Validators need more resources than regular nodes:

```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4"
  limits:
    memory: "16Gi"
    cpu: "8"
```

### 5. High Availability Considerations

For production validators:

- **Single Instance**: Validators should NOT be horizontally scaled (risk of double-signing)
- **Node Affinity**: Pin to specific nodes for consistent performance
- **Storage**: Use high-performance SSD storage with backup
- **Network**: Ensure stable, low-latency network connections
- **Monitoring**: 24/7 monitoring and alerting

## Validator Operations

### Starting a Validator

```bash
# Deploy with our script
./scripts/deploy.sh -n testnet -c validator -k your-password -t your-tofnd-password
```

### Monitoring Validator Health

```bash
# Check validator status
kubectl port-forward svc/axelar-validator-service 26657:26657 -n axelar-testnet
curl -s http://localhost:26657/status | jq '.result.validator_info'

# Check if validator is in active set
axelard query staking validators --node http://localhost:26657 | grep $(axelard tendermint show-address)

# Monitor signing
axelard query slashing signing-info $(axelard tendermint show-validator) --node http://localhost:26657
```

### Validator Maintenance

```bash
# Graceful shutdown
kubectl scale deployment axelar-validator --replicas=0 -n axelar-testnet

# Update configuration
kubectl edit configmap axelar-config -n axelar-testnet

# Restart validator
kubectl rollout restart deployment/axelar-validator -n axelar-testnet
```

## Troubleshooting

### Common Validator Issues

1. **Double Signing**: Never run the same validator key on multiple instances
2. **Key Corruption**: Regularly backup and verify key integrity
3. **Network Partitions**: Ensure stable network connectivity
4. **Resource Exhaustion**: Monitor CPU, memory, and disk usage
5. **Sync Issues**: Ensure proper peer connections

### Diagnostic Commands

```bash
# Check validator containers
kubectl get pods -n axelar-testnet -l app.kubernetes.io/component=validator

# Check individual container logs
kubectl logs deployment/axelar-validator -c axelar-validator -n axelar-testnet --tail=100
kubectl logs deployment/axelar-validator -c vald -n axelar-testnet --tail=100
kubectl logs deployment/axelar-validator -c tofnd -n axelar-testnet --tail=100

# Check validator metrics
kubectl port-forward svc/axelar-validator-service 26660:26660 -n axelar-testnet
curl http://localhost:26660/metrics | grep tendermint_consensus

# Check tofnd connectivity
kubectl exec -it deployment/axelar-validator -c tofnd -n axelar-testnet -- tofnd --help
```

## Security Best Practices

### Key Security
- Store mnemonics offline in secure locations
- Use hardware security modules (HSM) for production
- Implement key rotation procedures
- Regular security audits

### Operational Security
- Limit access to validator infrastructure
- Use VPN for remote access
- Implement proper logging and monitoring
- Regular security updates

### Network Security
- Use private networks where possible
- Implement DDoS protection
- Monitor for unusual network activity
- Use secure communication channels

## Conclusion

Setting up an Axelar validator requires careful attention to security, monitoring, and operational procedures. The Kubernetes deployment provides a robust foundation, but proper key management and monitoring are critical for successful validator operations.

Remember:
- **Never run the same validator key on multiple instances**
- **Always backup your keys securely**
- **Monitor your validator 24/7**
- **Keep your software updated**
- **Have an incident response plan**
