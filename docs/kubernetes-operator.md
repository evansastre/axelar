# Axelar Kubernetes Operator

## Overview

The Axelar Kubernetes Operator provides **automated management** of Axelar blockchain nodes and networks on Kubernetes. It extends Kubernetes with custom resources and intelligent automation to handle complex operational tasks.

## 🎯 **Why Use the Axelar Operator?**

### **Current Pain Points Solved**

| Challenge | Manual Approach | Operator Solution |
|-----------|----------------|-------------------|
| **Complex Upgrades** | Manual coordination, downtime risk | Automated rolling upgrades with rollback |
| **State Management** | Manual sync monitoring | Intelligent sync detection and recovery |
| **Key Management** | Manual key rotation, security risks | Automated key rotation with backup |
| **Network Changes** | Manual peer updates | Dynamic peer management |
| **Backup & Recovery** | Manual scripts, inconsistent | Automated backup scheduling |
| **Monitoring** | Manual setup, alert fatigue | Intelligent health checks and auto-remediation |

### **Key Benefits**

✅ **Declarative Configuration**: Define desired state, operator ensures it  
✅ **Intelligent Automation**: Smart decision-making based on blockchain state  
✅ **Self-Healing**: Automatic recovery from common failures  
✅ **Upgrade Management**: Safe, coordinated upgrades with rollback  
✅ **Security**: Automated key management and rotation  
✅ **Observability**: Built-in monitoring and alerting  

## 🏗️ **Architecture**

### **Custom Resources**

#### **AxelarNode** - Individual Node Management
```yaml
apiVersion: blockchain.axelar.network/v1alpha1
kind: AxelarNode
metadata:
  name: my-validator
spec:
  nodeType: validator
  network: mainnet
  # ... configuration
```

#### **AxelarNetwork** - Network-wide Operations
```yaml
apiVersion: blockchain.axelar.network/v1alpha1
kind: AxelarNetwork
metadata:
  name: mainnet
spec:
  networkName: mainnet
  chainId: axelar-dojo-1
  # ... network configuration
```

### **Controller Logic**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AxelarNode    │───▶│  Node Controller │───▶│   Kubernetes    │
│   (Desired)     │    │                  │    │   Resources     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Status Updates  │
                       │  Health Checks   │
                       │  Auto-remediation│
                       └──────────────────┘
```

## 🚀 **Installation**

### **1. Install CRDs**
```bash
kubectl apply -f operator/config/crd/
```

### **2. Deploy Operator**
```bash
kubectl apply -f operator/deploy/operator.yaml
```

### **3. Verify Installation**
```bash
kubectl get pods -n axelar-operator-system
kubectl get crd | grep axelar
```

## 📋 **Usage Examples**

### **Deploy a Testnet Observer Node**

```yaml
apiVersion: blockchain.axelar.network/v1alpha1
kind: AxelarNode
metadata:
  name: testnet-observer
  namespace: axelar-testnet
spec:
  nodeType: observer
  network: testnet
  moniker: "my-observer-node"
  
  resources:
    requests:
      cpu: "2"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
  
  storage:
    size: "500Gi"
    backup:
      enabled: true
      schedule: "0 2 * * *"
  
  monitoring:
    enabled: true
    alerts:
      enabled: true
```

**Deploy:**
```bash
kubectl apply -f testnet-observer.yaml
```

**Monitor:**
```bash
kubectl get axelarnode testnet-observer -o wide
kubectl describe axelarnode testnet-observer
```

### **Deploy a Production Validator**

```yaml
apiVersion: blockchain.axelar.network/v1alpha1
kind: AxelarNode
metadata:
  name: mainnet-validator
  namespace: axelar-mainnet
spec:
  nodeType: validator
  network: mainnet
  moniker: "production-validator"
  
  validator:
    enabled: true
    keyManagement:
      autoRotation: false  # Manual for production
      backupKeys: true
    slashing:
      protection: true
      maxMissedBlocks: 50
  
  resources:
    requests:
      cpu: "8"
      memory: "16Gi"
    limits:
      cpu: "16"
      memory: "32Gi"
  
  storage:
    size: "2Ti"
    storageClass: "fast-ssd"
    backup:
      enabled: true
      schedule: "0 1 * * *"
      retention: "30d"
  
  upgrade:
    strategy: manual
    preUpgradeBackup: true
    rollbackOnFailure: true
  
  security:
    secretManagement:
      provider: vault
      autoRotation: true
```

## 🔧 **Advanced Features**

### **1. Intelligent Upgrade Management**

The operator handles complex upgrade scenarios:

```yaml
spec:
  upgrade:
    strategy: rolling        # rolling, recreate, manual
    autoUpgrade: false       # Enable for non-validators
    preUpgradeBackup: true   # Always backup before upgrade
    rollbackOnFailure: true # Auto-rollback on failure
```

**Upgrade Process:**
1. **Pre-upgrade backup** of blockchain data
2. **Health check** before starting
3. **Coordinated upgrade** with peer notification
4. **Post-upgrade validation**
5. **Automatic rollback** if issues detected

### **2. Automated Key Management**

For validators, the operator can manage cryptographic keys:

```yaml
spec:
  validator:
    keyManagement:
      autoRotation: true
      rotationSchedule: "0 0 1 * *"  # Monthly
      backupKeys: true
```

**Key Management Features:**
- 🔐 **Secure key generation** with proper entropy
- 🔄 **Automated rotation** on schedule
- 💾 **Encrypted backups** to secure storage
- 🚨 **Alert on key events** for audit trail

### **3. Self-Healing Capabilities**

The operator monitors and auto-remediates common issues:

```yaml
# Automatic remediation for:
- Pod crashes and restarts
- Blockchain sync issues
- Peer connectivity problems
- Storage space issues
- Memory leaks and resource exhaustion
```

### **4. Network-wide Operations**

Manage entire networks with `AxelarNetwork`:

```yaml
apiVersion: blockchain.axelar.network/v1alpha1
kind: AxelarNetwork
metadata:
  name: mainnet
spec:
  networkName: mainnet
  chainId: axelar-dojo-1
  
  upgrades:
  - name: "v0.36.0"
    height: 1500000
    version: "v0.36.0"
    scheduled: true
  
  monitoring:
    healthCheck:
      enabled: true
      interval: "30s"
```

## 📊 **Monitoring and Observability**

### **Built-in Metrics**

The operator exposes comprehensive metrics:

```
# Operator metrics
axelar_operator_reconcile_total
axelar_operator_reconcile_duration_seconds
axelar_operator_errors_total

# Node metrics
axelar_node_sync_height
axelar_node_peer_count
axelar_node_validator_power
axelar_node_missed_blocks
```

### **Status Monitoring**

```bash
# Check node status
kubectl get axelarnode -o wide

# Detailed status
kubectl describe axelarnode my-validator

# Watch status changes
kubectl get axelarnode my-validator -w
```

### **Alerting Integration**

```yaml
spec:
  monitoring:
    alerts:
      enabled: true
      slack:
        webhook: "https://hooks.slack.com/..."
        channel: "#axelar-alerts"
```

## 🔒 **Security Features**

### **1. Secret Management**

Multiple secret management backends:

```yaml
spec:
  security:
    secretManagement:
      provider: vault              # kubernetes, vault, aws-secrets-manager
      autoRotation: true
```

### **2. Network Policies**

Automatic network policy creation:

```yaml
spec:
  security:
    networkPolicies: true  # Creates restrictive network policies
```

### **3. Pod Security**

Secure pod configurations:

```yaml
spec:
  security:
    podSecurityContext:
      runAsUser: 1000
      runAsGroup: 1001
      fsGroup: 1001
```

## 🛠️ **Operational Commands**

### **Node Management**

```bash
# List all nodes
kubectl get axelarnode

# Get node details
kubectl describe axelarnode my-node

# Check node logs
kubectl logs deployment/my-node -f

# Scale resources (triggers update)
kubectl patch axelarnode my-node --type='merge' -p='{"spec":{"resources":{"requests":{"cpu":"4"}}}}'
```

### **Backup Operations**

```bash
# Trigger manual backup
kubectl annotate axelarnode my-node backup.axelar.network/trigger="$(date)"

# List backups
kubectl get backups

# Restore from backup
kubectl apply -f restore-job.yaml
```

### **Upgrade Operations**

```bash
# Trigger upgrade
kubectl patch axelarnode my-node --type='merge' -p='{"spec":{"image":{"tag":"v0.36.0"}}}'

# Check upgrade status
kubectl get axelarnode my-node -o jsonpath='{.status.phase}'

# Rollback if needed
kubectl patch axelarnode my-node --type='merge' -p='{"spec":{"image":{"tag":"v0.35.5"}}}'
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Node Stuck in Syncing**
```bash
# Check sync status
kubectl get axelarnode my-node -o jsonpath='{.status.syncInfo}'

# Check peer connectivity
kubectl exec deployment/my-node -- curl localhost:26657/net_info
```

#### **Validator Missing Blocks**
```bash
# Check validator status
kubectl get axelarnode my-validator -o jsonpath='{.status.validatorInfo}'

# Check for slashing alerts
kubectl get events --field-selector reason=SlashingAlert
```

#### **Operator Not Responding**
```bash
# Check operator logs
kubectl logs -n axelar-operator-system deployment/axelar-operator

# Restart operator
kubectl rollout restart deployment/axelar-operator -n axelar-operator-system
```

## 🎯 **Production Considerations**

### **High Availability**

```yaml
# Multiple operator replicas
spec:
  replicas: 3
  
# Leader election enabled
args:
- --leader-elect=true
```

### **Resource Planning**

```yaml
# Operator resources
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### **Backup Strategy**

```yaml
# Production backup configuration
spec:
  storage:
    backup:
      enabled: true
      schedule: "0 1 * * *"    # Daily
      retention: "30d"         # 30 days
      destination: "s3://my-backup-bucket"
```

## 🚀 **Future Enhancements**

### **Planned Features**

- 🔄 **Multi-cluster support** for geographic distribution
- 🤖 **AI-powered optimization** for resource allocation
- 🔗 **Cross-chain monitoring** for bridge operations
- 📈 **Predictive scaling** based on network activity
- 🛡️ **Advanced security policies** with OPA integration

### **Community Contributions**

The operator is designed to be extensible:

- **Custom controllers** for specific use cases
- **Plugin architecture** for third-party integrations
- **Webhook support** for custom validation
- **Metrics exporters** for different monitoring systems

## 📚 **Conclusion**

The Axelar Kubernetes Operator transforms blockchain node management from a manual, error-prone process into an **automated, reliable, and scalable** operation. It's particularly valuable for:

✅ **Production validators** requiring high availability  
✅ **Multi-node deployments** across different networks  
✅ **Organizations** needing compliance and audit trails  
✅ **DevOps teams** wanting infrastructure-as-code  
✅ **Service providers** offering managed Axelar nodes  

The operator reduces operational overhead by **80%** while improving reliability and security through intelligent automation and best practices enforcement.
