# Repository Configuration for GitOps

## 🎯 **Problem Solved**

The GitOps applications were using placeholder URLs (`YOUR_USERNAME`) instead of real repository URLs. This document explains how to configure them properly for your actual repository.

## 🚀 **Quick Solution**

### **Automated Configuration (Recommended)**

```bash
# Auto-detect and configure repository URLs
./scripts/configure-gitops-repo.sh
```

This script:
- ✅ Auto-detects your repository URL from `git remote`
- ✅ Updates all GitOps files with the correct URL
- ✅ Creates backup files for safety
- ✅ Validates the configuration

### **Manual Configuration**

If you prefer manual configuration:

```bash
# Replace YOUR_USERNAME with your actual GitHub username
find gitops/ -name "*.yaml" -exec sed -i 's|YOUR_USERNAME|yourusername|g' {} \;
```

## 📋 **What Gets Updated**

### **Files Modified**

| File | Purpose | URL Pattern |
|------|---------|-------------|
| `gitops/applications/axelar-project.yaml` | Project-level repository access | `sourceRepos` list |
| `gitops/applications/axelar-operator.yaml` | Operator deployment source | `spec.source.repoURL` |
| `gitops/applications/axelar-testnet.yaml` | Testnet environment source | `spec.source.repoURL` |
| `gitops/applications/axelar-mainnet.yaml` | Mainnet environment source | `spec.source.repoURL` |
| `gitops/applications/axelar-applicationset.yaml` | Multi-environment management | Multiple `repoURL` fields |
| `gitops/environments/testnet/kustomization.yaml` | Testnet metadata | `config.kubernetes.io/origin` |
| `gitops/environments/mainnet/kustomization.yaml` | Mainnet metadata | `config.kubernetes.io/origin` |

### **Before Configuration**
```yaml
# Placeholder that needs updating
repoURL: https://github.com/YOUR_USERNAME/axelar-k8s-deployment
```

### **After Configuration**
```yaml
# Your actual repository
repoURL: https://github.com/yourusername/axelar-k8s-deployment
```

## 🔧 **Configuration Script Features**

### **Auto-Detection**
```bash
# Detects repository URL from git remote
git remote get-url origin
# Converts SSH to HTTPS format if needed
# git@github.com:user/repo.git → https://github.com/user/repo
```

### **Validation**
```bash
# Checks for valid URL format
if [[ ! "$REPO_URL" =~ ^https?:// && ! "$REPO_URL" =~ ^git@ ]]; then
    error "Invalid repository URL format"
fi
```

### **Safety Features**
- ✅ Creates `.backup` files before modification
- ✅ Dry-run mode to preview changes
- ✅ Validates configuration after update
- ✅ Provides rollback instructions

## 🌐 **Repository URL Formats**

### **Supported Formats**

| Format | Example | Use Case |
|--------|---------|----------|
| **HTTPS** | `https://github.com/user/repo` | Public repositories |
| **HTTPS with token** | `https://token@github.com/user/repo` | Private repositories |
| **SSH** | `git@github.com:user/repo.git` | SSH key authentication |
| **GitLab** | `https://gitlab.com/user/repo` | GitLab repositories |
| **Enterprise** | `https://git.company.com/user/repo` | Enterprise Git servers |

### **Auto-Conversion**
The script automatically converts SSH URLs to HTTPS format:
```bash
# Input:  git@github.com:user/repo.git
# Output: https://github.com/user/repo
```

## 🔒 **Private Repository Setup**

### **For Private Repositories**

If your repository is private, you need to configure ArgoCD credentials:

#### **Option 1: Personal Access Token**
```bash
# Create repository secret
kubectl create secret generic private-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/yourusername/axelar-k8s-deployment \
  --from-literal=username=yourusername \
  --from-literal=password=ghp_your_token_here \
  -n argocd

# Label for ArgoCD
kubectl label secret private-repo argocd.argoproj.io/secret-type=repository -n argocd
```

#### **Option 2: SSH Key**
```bash
# Create SSH key secret
kubectl create secret generic private-repo-ssh \
  --from-file=sshPrivateKey=/path/to/private/key \
  --from-literal=type=git \
  --from-literal=url=git@github.com:yourusername/axelar-k8s-deployment.git \
  -n argocd

# Label for ArgoCD
kubectl label secret private-repo-ssh argocd.argoproj.io/secret-type=repository -n argocd
```

## 🏢 **Enterprise Scenarios**

### **Multi-Repository Organizations**

For organizations with multiple repositories:

```bash
# Configure different repositories for different environments
./scripts/configure-gitops-repo.sh -r https://github.com/myorg/axelar-k8s-deployment-dev

# Then manually update production to use different repo
sed -i 's|myorg/axelar-k8s-deployment-dev|myorg/axelar-k8s-deployment-prod|g' \
  gitops/applications/axelar-mainnet.yaml
```

### **Branch-Based Environments**

```yaml
# Use different branches for different environments
# gitops/applications/axelar-testnet.yaml
spec:
  source:
    repoURL: https://github.com/myorg/axelar-k8s-deployment
    targetRevision: develop  # Development branch

# gitops/applications/axelar-mainnet.yaml
spec:
  source:
    repoURL: https://github.com/myorg/axelar-k8s-deployment
    targetRevision: main     # Production branch
```

## 🔍 **Verification and Troubleshooting**

### **Verify Configuration**
```bash
# Check for remaining placeholders
grep -r "YOUR_USERNAME" gitops/
# Should return no results if properly configured

# Check repository access
argocd repo add https://github.com/yourusername/axelar-k8s-deployment
argocd repo list
```

### **Common Issues**

#### **Issue 1: Repository Access Denied**
```bash
# Symptoms
FATA[0001] rpc error: code = Unknown desc = authentication required

# Solution
# Add repository credentials (see Private Repository Setup above)
```

#### **Issue 2: Path Not Found**
```bash
# Symptoms
application path 'gitops/environments/testnet' does not exist

# Solution
# Verify repository structure matches expected paths
ls -la gitops/environments/testnet/
```

#### **Issue 3: Placeholder URLs Still Present**
```bash
# Symptoms
grep -r "YOUR_USERNAME" gitops/
# Returns results

# Solution
./scripts/configure-gitops-repo.sh -r https://github.com/yourusername/axelar-k8s-deployment
```

## 📊 **Configuration Examples**

### **Example 1: Personal Repository**
```bash
# Auto-detect from current git repository
cd /path/to/axelar-k8s-deployment
./scripts/configure-gitops-repo.sh

# Output:
# [INFO] Auto-detecting repository URL...
# [INFO] Detected repository URL: https://github.com/johndoe/axelar-k8s-deployment
# [INFO] Configuring GitOps files with repository URL: https://github.com/johndoe/axelar-k8s-deployment
```

### **Example 2: Organization Repository**
```bash
# Specify organization repository manually
./scripts/configure-gitops-repo.sh -r https://github.com/acme-corp/axelar-infrastructure

# Output:
# [INFO] Configuring GitOps files with repository URL: https://github.com/acme-corp/axelar-infrastructure
```

### **Example 3: Enterprise Git Server**
```bash
# Configure for enterprise Git server
./scripts/configure-gitops-repo.sh -r https://git.company.com/blockchain/axelar-k8s-deployment

# Output:
# [INFO] Configuring GitOps files with repository URL: https://git.company.com/blockchain/axelar-k8s-deployment
```

## 🎯 **Best Practices**

### **Repository Management**
✅ **Consistent naming**: Use standard repository names  
✅ **Clear structure**: Maintain organized directory structure  
✅ **Version tagging**: Tag stable releases for production  
✅ **Branch protection**: Require reviews for main branch  

### **Security**
✅ **Private repositories**: Use private repos for production  
✅ **Limited access**: Use deploy keys with minimal permissions  
✅ **Token rotation**: Regularly rotate access tokens  
✅ **Audit logging**: Enable Git audit logs  

### **Operations**
✅ **Backup configurations**: Keep backups before changes  
✅ **Test configurations**: Use dry-run mode first  
✅ **Monitor deployments**: Set up sync failure alerts  
✅ **Document changes**: Use descriptive commit messages  

## 🚀 **Quick Start Workflow**

```bash
# 1. Configure repository URLs
./scripts/configure-gitops-repo.sh

# 2. Review changes
git diff

# 3. Commit configuration
git add .
git commit -m "Configure GitOps repository URLs"
git push

# 4. Deploy ArgoCD
./scripts/deploy-argocd.sh

# 5. Verify applications
kubectl get applications -n argocd

# 6. Start GitOps workflow
# Make changes via Git → Create PR → Review → Merge → Auto-deploy
```

## 📚 **Related Documentation**

- [GitOps Setup Guide](gitops-setup.md) - Complete setup instructions
- [GitOps with ArgoCD](gitops-argocd.md) - Detailed GitOps workflow
- [ArgoCD Applications](../gitops/applications/) - Application definitions
- [Environment Configurations](../gitops/environments/) - Environment-specific configs

This repository configuration system ensures that your GitOps setup works with your actual repository structure, enabling seamless automated deployments through ArgoCD.
