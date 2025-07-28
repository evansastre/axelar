# GitOps Setup Guide

## 🚀 **Quick Setup**

### **Step 1: Configure Repository URLs**

Before deploying ArgoCD, you need to configure the GitOps files to use your actual repository URL instead of placeholder URLs.

#### **Option A: Auto-detect (Recommended)**
```bash
# Auto-detect repository URL from current git remote
./scripts/configure-gitops-repo.sh
```

#### **Option B: Manual Configuration**
```bash
# Specify repository URL manually
./scripts/configure-gitops-repo.sh -r https://github.com/yourusername/axelar-k8s-deployment
```

#### **Option C: Dry Run First**
```bash
# See what would be changed without making changes
./scripts/configure-gitops-repo.sh -d
```

### **Step 2: Deploy ArgoCD**

```bash
# Deploy ArgoCD with Axelar configuration
./scripts/deploy-argocd.sh
```

### **Step 3: Access ArgoCD UI**

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Login: admin / admin123 (or your custom password)
```

## 📋 **Repository Configuration Details**

### **What Gets Updated**

The configuration script updates these files:

```
gitops/applications/
├── axelar-project.yaml          # Project-level repository access
├── axelar-operator.yaml         # Operator deployment
├── axelar-testnet.yaml          # Testnet environment
├── axelar-mainnet.yaml          # Mainnet environment
└── axelar-applicationset.yaml   # Multi-environment management

gitops/environments/
├── testnet/kustomization.yaml   # Testnet configuration
└── mainnet/kustomization.yaml   # Mainnet configuration

gitops/config/
└── repository.yaml              # Repository metadata
```

### **Before Configuration**
```yaml
# Placeholder URLs that need to be updated
repoURL: https://github.com/YOUR_USERNAME/axelar-k8s-deployment
```

### **After Configuration**
```yaml
# Your actual repository URL
repoURL: https://github.com/yourusername/axelar-k8s-deployment
```

## 🔧 **Manual Configuration (Alternative)**

If you prefer to configure manually:

### **1. Find and Replace**

```bash
# Replace placeholder URLs with your repository
find gitops/ -name "*.yaml" -exec sed -i 's|YOUR_USERNAME|yourusername|g' {} \;
```

### **2. Update Repository URLs**

Edit these files and replace `YOUR_USERNAME` with your actual GitHub username:

- `gitops/applications/axelar-project.yaml`
- `gitops/applications/axelar-operator.yaml`
- `gitops/applications/axelar-testnet.yaml`
- `gitops/applications/axelar-mainnet.yaml`
- `gitops/applications/axelar-applicationset.yaml`

### **3. Update Environment Configurations**

Edit these files:
- `gitops/environments/testnet/kustomization.yaml`
- `gitops/environments/mainnet/kustomization.yaml`

## 🔒 **Private Repository Setup**

If using a private repository, you need to configure credentials:

### **Option 1: SSH Key**

```bash
# Create SSH key secret
kubectl create secret generic private-repo-creds \
  --from-file=sshPrivateKey=/path/to/private/key \
  --from-literal=type=git \
  --from-literal=url=git@github.com:yourusername/axelar-k8s-deployment.git \
  -n argocd

# Label the secret
kubectl label secret private-repo-creds argocd.argoproj.io/secret-type=repository -n argocd
```

### **Option 2: HTTPS Token**

```bash
# Create HTTPS token secret
kubectl create secret generic private-repo-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/yourusername/axelar-k8s-deployment \
  --from-literal=username=yourusername \
  --from-literal=password=your-github-token \
  -n argocd

# Label the secret
kubectl label secret private-repo-creds argocd.argoproj.io/secret-type=repository -n argocd
```

## 🌐 **Multi-Repository Setup**

For organizations using multiple repositories:

### **1. Fork Structure**
```
Organization Repositories:
├── axelar-k8s-deployment (main)
├── axelar-k8s-deployment-dev (development)
├── axelar-k8s-deployment-staging (staging)
└── axelar-k8s-deployment-prod (production)
```

### **2. Environment-Specific URLs**

Update each environment to use different repositories:

```yaml
# gitops/applications/axelar-testnet.yaml
spec:
  source:
    repoURL: https://github.com/yourorg/axelar-k8s-deployment-dev

# gitops/applications/axelar-mainnet.yaml
spec:
  source:
    repoURL: https://github.com/yourorg/axelar-k8s-deployment-prod
```

## 🔍 **Verification**

### **Check Configuration**

```bash
# Verify no placeholder URLs remain
grep -r "YOUR_USERNAME" gitops/

# Should return no results if properly configured
```

### **Test Repository Access**

```bash
# Test if ArgoCD can access your repository
argocd repo add https://github.com/yourusername/axelar-k8s-deployment

# List repositories
argocd repo list
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Repository Access Denied**
```bash
# Check repository credentials
kubectl get secrets -n argocd | grep repo

# Check ArgoCD logs
kubectl logs -f deployment/argocd-repo-server -n argocd
```

#### **Application Sync Failures**
```bash
# Check application status
argocd app get axelar-testnet-nodes

# Check for path issues
argocd app diff axelar-testnet-nodes
```

#### **Placeholder URLs Still Present**
```bash
# Find remaining placeholders
grep -r "YOUR_USERNAME" gitops/

# Re-run configuration script
./scripts/configure-gitops-repo.sh -r https://github.com/yourusername/axelar-k8s-deployment
```

## 📚 **Best Practices**

### **Repository Management**

✅ **Use consistent naming**: `axelar-k8s-deployment`  
✅ **Tag releases**: Use semantic versioning for stable deployments  
✅ **Branch protection**: Require PR reviews for main branch  
✅ **Separate environments**: Use different branches or repositories  

### **Security**

✅ **Private repositories**: For production deployments  
✅ **Limited access**: Use deploy keys with read-only access  
✅ **Credential rotation**: Regularly rotate access tokens  
✅ **Audit logging**: Enable Git audit logs  

### **Operations**

✅ **Backup configurations**: Keep backups of working configurations  
✅ **Test changes**: Use dry-run before applying  
✅ **Monitor sync status**: Set up alerts for sync failures  
✅ **Document changes**: Use descriptive commit messages  

## 🎯 **Next Steps**

After configuring repository URLs:

1. **Commit Changes**:
   ```bash
   git add .
   git commit -m "Configure GitOps repository URLs"
   git push
   ```

2. **Deploy ArgoCD**:
   ```bash
   ./scripts/deploy-argocd.sh
   ```

3. **Verify Applications**:
   ```bash
   kubectl get applications -n argocd
   ```

4. **Start GitOps Workflow**:
   - Make infrastructure changes via Git
   - Create pull requests for reviews
   - Merge to trigger deployments

## 📖 **Additional Resources**

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kubernetes GitOps Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Git Workflow Guide](docs/gitops-argocd.md)
