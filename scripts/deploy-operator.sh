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
SKIP_CRD=false
NAMESPACE="axelar-operator-system"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy the Axelar Kubernetes Operator"
    echo ""
    echo "Options:"
    echo "  -d, --dry-run          Perform a dry run"
    echo "  -s, --skip-crd         Skip CRD installation"
    echo "  -n, --namespace NS     Operator namespace [default: axelar-operator-system]"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy operator"
    echo "  $0"
    echo ""
    echo "  # Dry run deployment"
    echo "  $0 -d"
    echo ""
    echo "  # Skip CRD installation (if already installed)"
    echo "  $0 -s"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-crd)
            SKIP_CRD=true
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
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

# Check if operator is already installed
if kubectl get deployment axelar-operator -n "$NAMESPACE" &> /dev/null; then
    warn "Axelar operator is already installed in namespace $NAMESPACE"
    read -p "Do you want to continue and update it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled"
        exit 0
    fi
fi

log "Deploying Axelar Kubernetes Operator..."
debug "Namespace: $NAMESPACE"
debug "Dry run: $DRY_RUN"
debug "Skip CRD: $SKIP_CRD"

# Install CRDs
if [[ "$SKIP_CRD" == "false" ]]; then
    log "Installing Custom Resource Definitions..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply --dry-run=client -f operator/config/crd/
    else
        kubectl apply -f operator/config/crd/
    fi
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log "Waiting for CRDs to be established..."
        kubectl wait --for condition=established --timeout=60s crd/axelarnodes.blockchain.axelar.network
        kubectl wait --for condition=established --timeout=60s crd/axelarnetworks.blockchain.axelar.network
    fi
else
    log "Skipping CRD installation"
fi

# Deploy operator
log "Deploying operator..."

if [[ "$DRY_RUN" == "true" ]]; then
    kubectl apply --dry-run=client -f operator/deploy/operator.yaml
else
    kubectl apply -f operator/deploy/operator.yaml
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run completed successfully!"
    exit 0
fi

# Wait for operator to be ready
log "Waiting for operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/axelar-operator -n "$NAMESPACE"

# Verify installation
log "Verifying installation..."

# Check operator pod
OPERATOR_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=axelar-operator -o jsonpath='{.items[0].metadata.name}')
if [[ -z "$OPERATOR_POD" ]]; then
    error "Operator pod not found"
fi

log "Operator pod: $OPERATOR_POD"

# Check operator logs
log "Checking operator logs..."
kubectl logs -n "$NAMESPACE" "$OPERATOR_POD" --tail=10

# Check CRDs
log "Checking Custom Resource Definitions..."
kubectl get crd | grep axelar

# Check operator metrics
log "Checking operator metrics endpoint..."
if kubectl get service axelar-operator-metrics -n "$NAMESPACE" &> /dev/null; then
    log "✅ Metrics service is available"
else
    warn "⚠️ Metrics service not found"
fi

# Show status
log "Deployment completed successfully!"
echo
log "Operator Status:"
kubectl get deployment axelar-operator -n "$NAMESPACE"
echo
log "Available Custom Resources:"
kubectl api-resources | grep axelar
echo

log "🎉 Axelar Kubernetes Operator is ready!"
echo
log "Next steps:"
log "  1. Create an AxelarNode resource:"
log "     kubectl apply -f operator/config/samples/testnet-observer.yaml"
log ""
log "  2. Check the node status:"
log "     kubectl get axelarnode -o wide"
log ""
log "  3. Monitor operator logs:"
log "     kubectl logs -f deployment/axelar-operator -n $NAMESPACE"
log ""
log "  4. View operator metrics:"
log "     kubectl port-forward svc/axelar-operator-metrics 8080:8080 -n $NAMESPACE"
echo
log "Documentation: docs/kubernetes-operator.md"
