# Helm Deployment Guide

This guide covers deploying Axelar nodes and validators using Helm charts, which provides better templating, versioning, and package management compared to raw Kubernetes manifests.

## Overview

The Helm chart provides:
- **Templated Configuration**: Dynamic configuration based on values
- **Multiple Deployment Types**: Support for both nodes and validators
- **Environment-Specific Values**: Separate values files for different scenarios
- **Upgrade Management**: Easy upgrades and rollbacks
- **Dependency Management**: Automatic handling of dependencies

## Prerequisites

- Kubernetes cluster
- Helm 3.x installed
- kubectl configured

## Quick Start

### 1. Deploy a Testnet Node

```bash
# Using the deployment script
./scripts/deploy-helm.sh -t node -n testnet -k your-secure-password

# Or using Helm directly
helm install axelar-testnet-node helm/axelar-node/ \
  --namespace axelar-testnet \
  --create-namespace \
  --values helm/axelar-node/values-testnet-node.yaml \
  --set secrets.keyringPassword=your-secure-password
```

### 2. Deploy a Validator

```bash
# Using the deployment script
./scripts/deploy-helm.sh -t validator -n testnet -k your-password -p your-tofnd-password

# Or using Helm directly
helm install axelar-validator helm/axelar-node/ \
  --namespace axelar-testnet \
  --create-namespace \
  --values helm/axelar-node/values-validator.yaml \
  --set deploymentType=validator \
  --set validator.enabled=true \
  --set secrets.keyringPassword=your-password \
  --set secrets.tofndPassword=your-tofnd-password
```

## Chart Structure

```
helm/axelar-node/
├── Chart.yaml                 # Chart metadata
├── values.yaml               # Default values
├── values-testnet-node.yaml  # Testnet node values
├── values-validator.yaml     # Validator values
└── templates/
    ├── _helpers.tpl          # Template helpers
    ├── deployment.yaml       # Main deployment
    ├── service.yaml          # Services
    ├── configmap.yaml        # Configuration
    ├── secret.yaml           # Secrets
    ├── pvc.yaml             # Storage
    ├── serviceaccount.yaml   # Service account
    ├── ingress.yaml         # Ingress (optional)
    └── servicemonitor.yaml   # Prometheus monitoring
```

## Configuration Options

### Basic Configuration

```yaml
# Deployment type: node or validator
deploymentType: "node"

# Network configuration
network:
  name: "testnet"  # testnet or mainnet

# Node configuration
node:
  moniker: "my-axelar-node"
  resources:
    requests:
      memory: "4Gi"
      cpu: "2"
    limits:
      memory: "8Gi"
      cpu: "4"
```

### Validator Configuration

```yaml
# Enable validator mode
deploymentType: "validator"
validator:
  enabled: true
  
  # Validator resources
  resources:
    requests:
      memory: "8Gi"
      cpu: "4"
    limits:
      memory: "16Gi"
      cpu: "8"
  
  # Vald container resources
  vald:
    resources:
      requests:
        memory: "2Gi"
        cpu: "1"
  
  # Tofnd container resources
  tofnd:
    resources:
      requests:
        memory: "1Gi"
        cpu: "0.5"
    storage:
      size: "10Gi"
```

### Storage Configuration

```yaml
node:
  storage:
    size: "500Gi"
    storageClass: "fast-ssd"
    accessMode: "ReadWriteOnce"
  
  sharedStorage:
    size: "10Gi"
    storageClass: "standard"
```

### Security Configuration

```yaml
security:
  runAsUser: 1000
  runAsGroup: 1001
  fsGroup: 1001
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

secrets:
  keyringPassword: "your-password"
  tofndPassword: "your-tofnd-password"  # For validators
  # Optional: provide existing secret
  existingSecret: "my-axelar-secrets"
```

### Monitoring Configuration

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
    labels:
      monitoring: "prometheus"

service:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "26660"
    prometheus.io/path: "/metrics"
```

## Deployment Scenarios

### 1. Development/Testing

```yaml
# values-dev.yaml
deploymentType: "node"
network:
  name: "testnet"

node:
  resources:
    requests:
      memory: "2Gi"
      cpu: "1"
    limits:
      memory: "4Gi"
      cpu: "2"
  storage:
    size: "50Gi"

config:
  app:
    pruning: "everything"  # Minimal storage
  tendermint:
    logLevel: "debug"      # Verbose logging
```

Deploy:
```bash
helm install axelar-dev helm/axelar-node/ \
  --values values-dev.yaml \
  --set secrets.keyringPassword=dev-password
```

### 2. Production Node

```yaml
# values-prod-node.yaml
deploymentType: "node"
network:
  name: "mainnet"

node:
  moniker: "prod-axelar-node"
  resources:
    requests:
      memory: "8Gi"
      cpu: "4"
    limits:
      memory: "16Gi"
      cpu: "8"
  storage:
    size: "1Ti"
    storageClass: "fast-ssd"

monitoring:
  serviceMonitor:
    enabled: true
    interval: "15s"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values:
          - blockchain
```

Deploy:
```bash
helm install axelar-mainnet-node helm/axelar-node/ \
  --namespace axelar-mainnet \
  --create-namespace \
  --values values-prod-node.yaml \
  --set secrets.keyringPassword="$KEYRING_PASSWORD"
```

### 3. Production Validator

```yaml
# values-prod-validator.yaml
deploymentType: "validator"
validator:
  enabled: true

network:
  name: "mainnet"

node:
  moniker: "prod-axelar-validator"

validator:
  resources:
    requests:
      memory: "16Gi"
      cpu: "8"
    limits:
      memory: "32Gi"
      cpu: "16"

# High availability settings
podDisruptionBudget:
  enabled: true
  minAvailable: 1

priorityClassName: "high-priority"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values:
          - validator

tolerations:
- key: "validator"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

Deploy:
```bash
helm install axelar-mainnet-validator helm/axelar-node/ \
  --namespace axelar-mainnet \
  --create-namespace \
  --values values-prod-validator.yaml \
  --set secrets.keyringPassword="$KEYRING_PASSWORD" \
  --set secrets.tofndPassword="$TOFND_PASSWORD"
```

## Advanced Usage

### Custom Configuration

You can override any configuration value:

```bash
helm install axelar-custom helm/axelar-node/ \
  --set node.moniker="my-custom-node" \
  --set node.resources.requests.memory="16Gi" \
  --set config.app.pruning="nothing" \
  --set service.type="LoadBalancer"
```

### Using External Secrets

```yaml
secrets:
  existingSecret: "axelar-external-secrets"
```

Create the external secret:
```bash
kubectl create secret generic axelar-external-secrets \
  --from-literal=keyring-password="$KEYRING_PASSWORD" \
  --from-literal=tofnd-password="$TOFND_PASSWORD" \
  --from-file=validator-mnemonic=./validator.txt \
  --from-file=tofnd-mnemonic=./tofnd.txt
```

### Ingress Configuration

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: axelar-rpc.example.com
      paths:
        - path: /
          pathType: Prefix
          port: 26657
  tls:
    - secretName: axelar-rpc-tls
      hosts:
        - axelar-rpc.example.com
```

## Management Operations

### Upgrade Deployment

```bash
# Upgrade with new values
helm upgrade axelar-node helm/axelar-node/ \
  --values new-values.yaml

# Upgrade with script
./scripts/deploy-helm.sh -t node -n testnet -k password -u
```

### Rollback Deployment

```bash
# List releases
helm history axelar-node

# Rollback to previous version
helm rollback axelar-node

# Rollback to specific revision
helm rollback axelar-node 2
```

### Scale Resources

```bash
# Scale up resources
helm upgrade axelar-node helm/axelar-node/ \
  --reuse-values \
  --set node.resources.requests.memory="16Gi" \
  --set node.resources.requests.cpu="8"
```

### Update Configuration

```bash
# Update configuration
helm upgrade axelar-node helm/axelar-node/ \
  --reuse-values \
  --set config.app.pruning="nothing" \
  --set config.tendermint.logLevel="debug"
```

## Monitoring and Debugging

### Check Deployment Status

```bash
# Helm status
helm status axelar-node

# Kubernetes resources
kubectl get all -l app.kubernetes.io/instance=axelar-node

# Pod logs
kubectl logs -f deployment/axelar-node
```

### Debug Issues

```bash
# Dry run to check configuration
helm install axelar-node helm/axelar-node/ \
  --dry-run --debug \
  --values values.yaml

# Template rendering
helm template axelar-node helm/axelar-node/ \
  --values values.yaml

# Check generated manifests
helm get manifest axelar-node
```

### Access Services

```bash
# Port forward RPC
kubectl port-forward svc/axelar-node-service 26657:26657

# Port forward Prometheus metrics
kubectl port-forward svc/axelar-node-service 26660:26660

# Test connectivity
curl http://localhost:26657/status
curl http://localhost:26660/metrics
```

## Best Practices

### 1. Use Values Files

Always use values files instead of inline `--set` commands for complex configurations:

```bash
# Good
helm install axelar-node helm/axelar-node/ --values production-values.yaml

# Avoid for complex configs
helm install axelar-node helm/axelar-node/ --set a=b --set c=d --set e=f
```

### 2. Version Control

Keep your values files in version control:

```
values/
├── dev-values.yaml
├── staging-values.yaml
└── production-values.yaml
```

### 3. Secret Management

Use external secret management:

```bash
# Use external secrets operator
kubectl apply -f external-secret.yaml

# Or use sealed secrets
kubeseal -f secret.yaml -w sealed-secret.yaml
```

### 4. Resource Management

Always set resource requests and limits:

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2"
  limits:
    memory: "8Gi"
    cpu: "4"
```

### 5. Monitoring

Enable monitoring for all deployments:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
```

## Troubleshooting

### Common Issues

1. **Pod Stuck in Pending**
   ```bash
   kubectl describe pod <pod-name>
   # Check for resource constraints or node affinity issues
   ```

2. **Configuration Errors**
   ```bash
   helm template axelar-node helm/axelar-node/ --values values.yaml
   # Check generated templates for issues
   ```

3. **Secret Issues**
   ```bash
   kubectl get secrets
   kubectl describe secret axelar-node-secrets
   ```

4. **Storage Issues**
   ```bash
   kubectl get pvc
   kubectl describe pvc axelar-node-data
   ```

### Getting Help

```bash
# Chart help
helm show readme helm/axelar-node/

# Values documentation
helm show values helm/axelar-node/

# Chart information
helm show chart helm/axelar-node/
```

## Comparison: Helm vs Kustomize

| Feature | Helm | Kustomize |
|---------|------|-----------|
| **Templating** | Full templating with functions | Overlay-based patching |
| **Package Management** | Built-in versioning and repositories | No built-in packaging |
| **Complexity** | Higher learning curve | Simpler, more straightforward |
| **Reusability** | High - charts can be shared | Medium - bases can be reused |
| **Upgrade Management** | Built-in upgrade/rollback | Manual management |
| **Dependency Management** | Built-in | Manual |
| **Configuration** | Values-based | Patch-based |

## Conclusion

The Helm chart provides a more sophisticated deployment option compared to raw Kubernetes manifests or Kustomize. It's particularly useful for:

- **Production deployments** requiring sophisticated configuration management
- **Multi-environment deployments** with different configurations
- **Teams** that need package management and versioning
- **Complex deployments** with many configuration options

For simpler use cases, the existing Kustomize setup may be sufficient, but Helm provides more advanced features for production environments.
