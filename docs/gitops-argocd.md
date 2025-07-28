# GitOps with ArgoCD for Axelar Deployment

## Overview

This document describes the **GitOps workflow** using ArgoCD for managing Axelar blockchain infrastructure. GitOps provides **declarative, version-controlled, and automated** deployment processes that ensure consistency, auditability, and reliability.

## 🎯 **Why GitOps for Axelar?**

### **Traditional Deployment Challenges**

| Challenge | Impact | GitOps Solution |
|-----------|--------|-----------------|
| **Manual Deployments** | Human errors, inconsistency | Automated, declarative deployments |
| **Configuration Drift** | Production differs from code | Continuous reconciliation |
| **No Audit Trail** | Unknown changes, compliance issues | Git-based change tracking |
| **Rollback Complexity** | Difficult to revert changes | Git revert = infrastructure revert |
| **Multi-Environment Sync** | Dev/staging/prod inconsistencies | Environment-specific overlays |
| **Security Risks** | Direct cluster access needed | Pull-based, secure deployments |

### **GitOps Benefits for Blockchain Infrastructure**

✅ **Immutable Infrastructure**: Every change is tracked and versioned  
✅ **Disaster Recovery**: Complete infrastructure reproducible from Git  
✅ **Compliance**: Full audit trail of all changes  
✅ **Security**: No direct cluster access required  
✅ **Collaboration**: Code review process for infrastructure changes  
✅ **Rollback**: Instant rollback to any previous state  

## 🏗️ **Architecture**

### **GitOps Flow**

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Developer   │───▶│ Git Repository│───▶│ ArgoCD          │───▶│ Kubernetes      │
│ Push Changes│    │ (Source of    │    │ (Deployment     │    │ (Target State)  │
│             │    │  Truth)       │    │  Agent)         │    │                 │
└─────────────┘    └──────────────┘    └─────────────────┘    └─────────────────┘
                           │                       │                       │
                           │                       ▼                       │
                           │            ┌─────────────────┐                │
                           │            │ Continuous      │                │
                           │            │ Monitoring      │                │
                           │            │ & Sync          │                │
                           │            └─────────────────┘                │
                           │                       │                       │
                           └───────────────────────┼───────────────────────┘
                                                   ▼
                                        ┌─────────────────┐
                                        │ Drift Detection │
                                        │ & Auto-healing  │
                                        └─────────────────┘
```

### **Repository Structure**

```
gitops/
├── argocd/                     # ArgoCD installation and configuration
│   └── install.yaml           # ArgoCD setup with Axelar customizations
├── applications/               # ArgoCD Application definitions
│   ├── axelar-project.yaml    # Project-level RBAC and policies
│   ├── axelar-operator.yaml   # Kubernetes Operator deployment
│   ├── axelar-testnet.yaml    # Testnet environment
│   ├── axelar-mainnet.yaml    # Mainnet environment
│   └── axelar-applicationset.yaml # Multi-environment management
├── environments/               # Environment-specific configurations
│   ├── testnet/               # Testnet overlay
│   │   ├── kustomization.yaml
│   │   ├── observer-node.yaml
│   │   ├── sentry-node.yaml
│   │   └── network.yaml
│   └── mainnet/               # Mainnet overlay
│       ├── kustomization.yaml
│       ├── validator-node.yaml
│       └── sentry-node.yaml
└── overlays/                   # Shared overlays
    ├── monitoring/
    ├── security/
    └── backup/
```

## 🚀 **Installation and Setup**

### **1. Deploy ArgoCD**

```bash
# Deploy ArgoCD with Axelar configuration
./scripts/deploy-argocd.sh

# Or with custom settings
./scripts/deploy-argocd.sh -p 'my-secure-password' -n argocd
```

### **2. Access ArgoCD UI**

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Login: admin / admin123 (or your custom password)
```

### **3. Install ArgoCD CLI (Optional)**

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login via CLI
argocd login localhost:8080 --username admin --password admin123 --insecure
```

## 📋 **Application Management**

### **Axelar Project Structure**

The GitOps setup includes several ArgoCD applications:

#### **1. Infrastructure Applications**

```yaml
# axelar-operator.yaml - Kubernetes Operator
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: axelar-operator
spec:
  project: axelar
  source:
    repoURL: https://github.com/axelar-network/axelar-k8s-deployment
    path: operator/deploy
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### **2. Environment Applications**

```yaml
# axelar-testnet.yaml - Testnet Environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: axelar-testnet-nodes
spec:
  project: axelar
  source:
    path: gitops/environments/testnet
  syncPolicy:
    automated:
      prune: true
      selfHeal: true  # Auto-sync for testnet
```

```yaml
# axelar-mainnet.yaml - Mainnet Environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: axelar-mainnet-validators
spec:
  project: axelar
  source:
    path: gitops/environments/mainnet
  syncPolicy:
    # Manual sync only for production
    syncOptions:
      - CreateNamespace=true
```

### **Application Sync Strategies**

| Environment | Sync Policy | Rationale |
|-------------|-------------|-----------|
| **Testnet** | Automated | Safe for testing, quick feedback |
| **Mainnet** | Manual | Production safety, controlled changes |
| **Operator** | Automated | Infrastructure component, self-healing |
| **Monitoring** | Automated | Non-critical, observability |

## 🔄 **Deployment Workflows**

### **1. Standard Deployment Flow**

```bash
# 1. Make changes to configuration
git checkout -b feature/update-axelar-version
vim gitops/environments/testnet/observer-node.yaml

# 2. Update image version
spec:
  image:
    tag: v0.36.0  # Updated version

# 3. Commit and push
git add .
git commit -m "Update Axelar testnet to v0.36.0"
git push origin feature/update-axelar-version

# 4. Create pull request
# 5. Review and merge
# 6. ArgoCD automatically syncs testnet (if automated)
# 7. Manually sync mainnet after validation
```

### **2. Emergency Rollback**

```bash
# Option 1: Git revert (recommended)
git revert <commit-hash>
git push origin main
# ArgoCD will automatically sync the rollback

# Option 2: ArgoCD rollback
argocd app rollback axelar-mainnet-validators <revision>

# Option 3: Manual sync to previous revision
argocd app sync axelar-mainnet-validators --revision <previous-commit>
```

### **3. Multi-Environment Promotion**

```bash
# Progressive deployment using ApplicationSet
# 1. Deploy to testnet (automatic)
# 2. Validate testnet deployment
# 3. Promote to mainnet (manual)

# Check testnet status
kubectl get axelarnode -n axelar-testnet

# If healthy, sync mainnet
argocd app sync axelar-mainnet-validators
```

## 🔧 **Advanced Features**

### **1. ApplicationSets for Multi-Environment**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: axelar-environments
spec:
  generators:
  - git:
      repoURL: https://github.com/axelar-network/axelar-k8s-deployment
      directories:
      - path: gitops/environments/*
  template:
    metadata:
      name: 'axelar-{{path.basename}}'
    spec:
      source:
        path: '{{path}}'
      destination:
        namespace: 'axelar-{{path.basename}}'
```

### **2. Progressive Rollouts**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: axelar-progressive-rollout
spec:
  strategy:
    type: RollingSync
    rollingSync:
      steps:
      - matchExpressions:
        - key: wave
          operator: In
          values: ["1"]  # Dev first
      - matchExpressions:
        - key: wave
          operator: In
          values: ["2"]  # Then staging
      - matchExpressions:
        - key: wave
          operator: In
          values: ["3"]  # Then testnet
      - matchExpressions:
        - key: wave
          operator: In
          values: ["4"]  # Finally mainnet
```

### **3. Sync Waves and Hooks**

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy order
    argocd.argoproj.io/hook: PreSync   # Lifecycle hooks
```

**Sync Wave Order**:
1. **Wave 0**: CRDs and namespaces
2. **Wave 1**: Operators and network configs
3. **Wave 2**: Node deployments
4. **Wave 3**: Monitoring and services

### **4. Health Checks for Custom Resources**

```yaml
# In ArgoCD ConfigMap
resource.customizations: |
  blockchain.axelar.network/AxelarNode:
    health.lua: |
      hs = {}
      if obj.status ~= nil then
        if obj.status.phase == "Running" then
          hs.status = "Healthy"
        elseif obj.status.phase == "Syncing" then
          hs.status = "Progressing"
        else
          hs.status = "Degraded"
        end
      end
      return hs
```

## 🔒 **Security and RBAC**

### **Project-Level Security**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: axelar
spec:
  # Restrict source repositories
  sourceRepos:
    - 'https://github.com/axelar-network/axelar-k8s-deployment'
  
  # Restrict destination namespaces
  destinations:
    - namespace: 'axelar-*'
      server: https://kubernetes.default.svc
  
  # RBAC roles
  roles:
  - name: developer
    policies:
      - p, proj:axelar:developer, applications, sync, axelar/axelar-testnet-*, allow
    groups:
      - axelar-developers
  
  - name: operator
    policies:
      - p, proj:axelar:operator, applications, *, axelar/axelar-testnet-*, allow
      - p, proj:axelar:operator, applications, get, axelar/axelar-mainnet-*, allow
    groups:
      - axelar-operators
```

### **Sync Windows**

```yaml
# Prevent mainnet deployments during peak hours
syncWindows:
- kind: deny
  schedule: '0 2-4 * * *'  # 2-4 AM UTC maintenance window
  duration: 2h
  applications:
    - axelar-mainnet-*
  manualSync: true
```

## 📊 **Monitoring and Observability**

### **ArgoCD Metrics**

ArgoCD exposes Prometheus metrics for monitoring:

```yaml
# Key metrics to monitor
argocd_app_health_status
argocd_app_sync_total
argocd_app_reconcile_duration_seconds
argocd_cluster_connection_status
```

### **Application Health Dashboard**

```bash
# Check application status
kubectl get applications -n argocd -o wide

# Watch for sync events
kubectl get events -n argocd --field-selector reason=ResourceUpdated -w

# Application details
argocd app get axelar-testnet-nodes
```

### **Notification Integration**

```yaml
# ArgoCD notifications for Slack
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: |
      {{if eq .serviceType "slack"}}:white_check_mark:{{end}} Application {{.app.metadata.name}} is now running new version.
  trigger.on-deployed: |
    - description: Application is synced and healthy
      send:
      - app-deployed
      when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
```

## 🛠️ **Operational Commands**

### **Application Management**

```bash
# List all applications
argocd app list

# Get application details
argocd app get axelar-testnet-nodes

# Sync application
argocd app sync axelar-testnet-nodes

# Check sync status
argocd app wait axelar-testnet-nodes --health

# View application logs
argocd app logs axelar-testnet-nodes

# Rollback application
argocd app rollback axelar-testnet-nodes <revision>
```

### **Troubleshooting**

```bash
# Check ArgoCD controller logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Check repo server logs
kubectl logs -f deployment/argocd-repo-server -n argocd

# Check application events
kubectl describe application axelar-testnet-nodes -n argocd

# Force refresh application
argocd app get axelar-testnet-nodes --refresh

# Hard refresh (ignore cache)
argocd app get axelar-testnet-nodes --hard-refresh
```

### **Repository Management**

```bash
# List repositories
argocd repo list

# Add repository
argocd repo add https://github.com/axelar-network/axelar-k8s-deployment

# Test repository connection
argocd repo get https://github.com/axelar-network/axelar-k8s-deployment
```

## 🔄 **CI/CD Integration**

### **GitHub Actions Integration**

```yaml
# .github/workflows/gitops.yml
name: GitOps Validation
on:
  pull_request:
    paths:
      - 'gitops/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Validate Kubernetes manifests
      run: |
        kubectl --dry-run=client apply -f gitops/environments/testnet/
    
    - name: ArgoCD diff
      run: |
        argocd app diff axelar-testnet-nodes --local gitops/environments/testnet/
    
    - name: Security scan
      run: |
        kubesec scan gitops/environments/testnet/*.yaml
```

### **Automated Testing**

```bash
# Test deployment in isolated namespace
kubectl create namespace test-deployment
kubectl apply -f gitops/environments/testnet/ -n test-deployment

# Run validation tests
kubectl wait --for=condition=available deployment/observer-node -n test-deployment --timeout=300s

# Cleanup
kubectl delete namespace test-deployment
```

## 📈 **Best Practices**

### **1. Repository Organization**

✅ **Separate environments** in different directories  
✅ **Use Kustomize overlays** for environment-specific configs  
✅ **Keep secrets external** (Vault, External Secrets Operator)  
✅ **Version control everything** including ArgoCD configuration  

### **2. Application Design**

✅ **Small, focused applications** rather than monolithic ones  
✅ **Use sync waves** for deployment ordering  
✅ **Implement health checks** for custom resources  
✅ **Set appropriate sync policies** per environment  

### **3. Security**

✅ **Use RBAC** to restrict access by role  
✅ **Implement sync windows** for production  
✅ **Enable audit logging** for compliance  
✅ **Use signed commits** for critical changes  

### **4. Operations**

✅ **Monitor application health** continuously  
✅ **Set up notifications** for sync failures  
✅ **Practice rollback procedures** regularly  
✅ **Document emergency procedures**  

## 🚨 **Troubleshooting Guide**

### **Common Issues**

#### **Application Stuck in Syncing**
```bash
# Check application status
argocd app get <app-name>

# Look for sync errors
kubectl describe application <app-name> -n argocd

# Force refresh
argocd app get <app-name> --hard-refresh
```

#### **Out of Sync Status**
```bash
# Compare desired vs actual state
argocd app diff <app-name>

# Check for manual changes
kubectl get <resource> -o yaml | grep -A5 -B5 "last-applied-configuration"

# Sync to resolve
argocd app sync <app-name>
```

#### **Health Check Failures**
```bash
# Check resource status
kubectl get <resource> -o yaml

# Check pod logs
kubectl logs <pod-name>

# Verify health check configuration
kubectl get configmap argocd-cm -n argocd -o yaml
```

## 🎯 **Production Considerations**

### **High Availability**

```yaml
# ArgoCD HA configuration
spec:
  replicas: 3
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: argocd-server
        topologyKey: kubernetes.io/hostname
```

### **Backup and Recovery**

```bash
# Backup ArgoCD configuration
kubectl get applications -n argocd -o yaml > argocd-applications-backup.yaml
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Backup secrets
kubectl get secrets -n argocd -o yaml > argocd-secrets-backup.yaml
```

### **Performance Tuning**

```yaml
# ArgoCD performance settings
data:
  application.resync: "300"  # 5 minutes
  timeout.reconciliation: "180s"
  timeout.hard.reconciliation: "0"
```

## 📚 **Conclusion**

GitOps with ArgoCD provides **enterprise-grade deployment automation** for Axelar infrastructure:

✅ **Declarative Infrastructure**: Everything defined in Git  
✅ **Automated Deployments**: Continuous synchronization  
✅ **Audit Trail**: Complete change history  
✅ **Security**: RBAC and controlled access  
✅ **Reliability**: Automated rollback and healing  
✅ **Scalability**: Multi-environment management  

The GitOps approach transforms infrastructure management from **manual, error-prone processes** into **automated, reliable, and auditable workflows** - essential for production blockchain infrastructure.

**Next Steps**:
1. Deploy ArgoCD using the provided scripts
2. Configure your Git repository with the GitOps structure
3. Set up RBAC and security policies
4. Implement monitoring and alerting
5. Practice deployment and rollback procedures
