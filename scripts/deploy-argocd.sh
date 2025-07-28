#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Default values
DRY_RUN=false
SKIP_INSTALL=false
ADMIN_PASSWORD="admin123"
NAMESPACE="argocd"
INSTALL_APPS=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy ArgoCD with Axelar GitOps configuration"
    echo ""
    echo "Options:"
    echo "  -d, --dry-run          Perform a dry run"
    echo "  -s, --skip-install     Skip ArgoCD installation (if already installed)"
    echo "  -p, --password PASS    Admin password [default: admin123]"
    echo "  -n, --namespace NS     ArgoCD namespace [default: argocd]"
    echo "  --skip-apps            Skip application deployment"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy ArgoCD with default settings"
    echo "  $0"
    echo ""
    echo "  # Deploy with custom password"
    echo "  $0 -p 'my-secure-password'"
    echo ""
    echo "  # Skip ArgoCD installation, only deploy apps"
    echo "  $0 -s"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-install)
            SKIP_INSTALL=true
            shift
            ;;
        -p|--password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-apps)
            INSTALL_APPS=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option $1"
            ;;
    esac
done

# Check prerequisites
log "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
fi

if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
fi

if ! command -v htpasswd &> /dev/null && [[ "$ADMIN_PASSWORD" != "admin123" ]]; then
    warn "htpasswd not found - using default password hash"
fi

log "Starting ArgoCD GitOps deployment..."
debug "Namespace: $NAMESPACE"
debug "Dry run: $DRY_RUN"
debug "Skip install: $SKIP_INSTALL"
debug "Install apps: $INSTALL_APPS"

# Install ArgoCD
if [[ "$SKIP_INSTALL" == "false" ]]; then
    log "Installing ArgoCD..."
    
    # Create namespace
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml
    else
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Install ArgoCD
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would install ArgoCD in namespace $NAMESPACE"
    else
        log "Installing ArgoCD core components..."
        kubectl apply -n "$NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        # Wait for ArgoCD to be ready
        log "Waiting for ArgoCD to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "$NAMESPACE"
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n "$NAMESPACE"
        kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n "$NAMESPACE"
    fi
    
    # Configure ArgoCD
    log "Configuring ArgoCD..."
    
    # Update admin password if not default
    if [[ "$ADMIN_PASSWORD" != "admin123" ]]; then
        if command -v htpasswd &> /dev/null; then
            HASHED_PASSWORD=$(htpasswd -bnBC 10 "" "$ADMIN_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')
        else
            warn "Using default password hash - please change password after login"
            HASHED_PASSWORD='$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/XhDlILz.bF8l9W'
        fi
        
        if [[ "$DRY_RUN" == "false" ]]; then
            kubectl patch secret argocd-secret -n "$NAMESPACE" \
                -p='{"stringData": {"admin.password": "'$HASHED_PASSWORD'", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'
        fi
    fi
    
    # Apply ArgoCD configuration
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply --dry-run=client -f gitops/argocd/install.yaml
    else
        kubectl apply -f gitops/argocd/install.yaml
    fi
    
else
    log "Skipping ArgoCD installation"
fi

# Deploy Axelar project and applications
if [[ "$INSTALL_APPS" == "true" ]]; then
    log "Deploying Axelar GitOps applications..."
    
    # Deploy project first
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply --dry-run=client -f gitops/applications/axelar-project.yaml
    else
        kubectl apply -f gitops/applications/axelar-project.yaml
    fi
    
    # Wait for project to be ready
    if [[ "$DRY_RUN" == "false" ]]; then
        sleep 5
    fi
    
    # Deploy applications in order
    applications=(
        "gitops/applications/axelar-operator.yaml"
        "gitops/applications/axelar-testnet.yaml"
        "gitops/applications/axelar-mainnet.yaml"
        "gitops/applications/axelar-applicationset.yaml"
    )
    
    for app in "${applications[@]}"; do
        log "Deploying $(basename "$app" .yaml)..."
        if [[ "$DRY_RUN" == "true" ]]; then
            kubectl apply --dry-run=client -f "$app"
        else
            kubectl apply -f "$app"
            sleep 2  # Brief pause between applications
        fi
    done
    
else
    log "Skipping application deployment"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run completed successfully!"
    exit 0
fi

# Verify installation
log "Verifying ArgoCD installation..."

# Check ArgoCD pods
ARGOCD_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/part-of=argocd --no-headers | wc -l)
if [[ "$ARGOCD_PODS" -lt 4 ]]; then
    warn "Expected at least 4 ArgoCD pods, found $ARGOCD_PODS"
else
    log "✅ ArgoCD pods are running ($ARGOCD_PODS pods)"
fi

# Check applications
if [[ "$INSTALL_APPS" == "true" ]]; then
    log "Checking ArgoCD applications..."
    sleep 10  # Wait for applications to be processed
    
    APPS=$(kubectl get applications -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ "$APPS" -gt 0 ]]; then
        log "✅ Found $APPS ArgoCD applications"
        kubectl get applications -n "$NAMESPACE" -o wide
    else
        warn "No ArgoCD applications found"
    fi
fi

# Get ArgoCD server info
ARGOCD_SERVER_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
if [[ -n "$ARGOCD_SERVER_POD" ]]; then
    log "✅ ArgoCD server pod: $ARGOCD_SERVER_POD"
else
    warn "ArgoCD server pod not found"
fi

log "🎉 ArgoCD GitOps deployment completed!"
echo
log "⚠️  IMPORTANT: Configure Repository URLs"
log "Before deploying applications, you need to configure the repository URLs:"
log "  ./scripts/configure-gitops-repo.sh"
log "  # This will update all GitOps files with your actual repository URL"
echo
log "Access Information:"
log "  Namespace: $NAMESPACE"
log "  Admin Username: admin"
log "  Admin Password: $ADMIN_PASSWORD"
echo
log "To access ArgoCD UI:"
log "  # Port forward to ArgoCD server"
log "  kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
log "  # Then open: https://localhost:8080"
echo
log "To use ArgoCD CLI:"
log "  # Install ArgoCD CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
log "  # Login to ArgoCD"
log "  argocd login localhost:8080 --username admin --password '$ADMIN_PASSWORD' --insecure"
echo
log "Useful commands:"
log "  # List applications"
log "  kubectl get applications -n $NAMESPACE"
log "  # Watch application sync status"
log "  kubectl get applications -n $NAMESPACE -w"
log "  # Check application details"
log "  kubectl describe application <app-name> -n $NAMESPACE"
echo
log "Documentation: docs/gitops-argocd.md"
