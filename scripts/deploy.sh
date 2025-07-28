#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NETWORK="testnet"
COMPONENT="node"
NAMESPACE="axelar-testnet"
KEYRING_PASSWORD=""
TOFND_PASSWORD=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Axelar node or validator to Kubernetes"
    echo ""
    echo "Options:"
    echo "  -n, --network NETWORK      Network to deploy (testnet|mainnet) [default: testnet]"
    echo "  -c, --component COMPONENT  Component to deploy (node|validator) [default: node]"
    echo "  -k, --keyring-password     Keyring password (required)"
    echo "  -t, --tofnd-password       Tofnd password (required for validator)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -n testnet -c node -k mypassword"
    echo "  $0 -n testnet -c validator -k mypassword -t mytofndpassword"
}

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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--network)
            NETWORK="$2"
            shift 2
            ;;
        -c|--component)
            COMPONENT="$2"
            shift 2
            ;;
        -k|--keyring-password)
            KEYRING_PASSWORD="$2"
            shift 2
            ;;
        -t|--tofnd-password)
            TOFND_PASSWORD="$2"
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

# Validation
if [[ "$NETWORK" != "testnet" && "$NETWORK" != "mainnet" ]]; then
    error "Network must be 'testnet' or 'mainnet'"
fi

if [[ "$COMPONENT" != "node" && "$COMPONENT" != "validator" ]]; then
    error "Component must be 'node' or 'validator'"
fi

if [[ -z "$KEYRING_PASSWORD" ]]; then
    error "Keyring password is required"
fi

if [[ "$COMPONENT" == "validator" && -z "$TOFND_PASSWORD" ]]; then
    error "Tofnd password is required for validator deployment"
fi

if [[ ${#KEYRING_PASSWORD} -lt 8 ]]; then
    error "Keyring password must be at least 8 characters long"
fi

# Set namespace based on network
if [[ "$NETWORK" == "mainnet" ]]; then
    NAMESPACE="axelar-mainnet"
fi

log "Deploying Axelar $COMPONENT to $NETWORK network in namespace $NAMESPACE"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
fi

# Create namespace if it doesn't exist
log "Creating namespace $NAMESPACE if it doesn't exist"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create secrets
log "Creating secrets"
if [[ "$COMPONENT" == "node" ]]; then
    kubectl create secret generic axelar-secrets \
        --from-literal=keyring-password="$KEYRING_PASSWORD" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
else
    kubectl create secret generic axelar-validator-secrets \
        --from-literal=keyring-password="$KEYRING_PASSWORD" \
        --from-literal=tofnd-password="$TOFND_PASSWORD" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Deploy based on component type
if [[ "$COMPONENT" == "node" ]]; then
    log "Deploying Axelar node"
    kubectl apply -k "k8s/$NETWORK/"
else
    log "Deploying Axelar validator"
    kubectl apply -f k8s/base/namespace.yaml
    kubectl apply -f k8s/base/configmap.yaml
    kubectl apply -f k8s/validator/
fi

# Wait for deployment to be ready
log "Waiting for deployment to be ready..."
if [[ "$COMPONENT" == "node" ]]; then
    kubectl wait --for=condition=available --timeout=600s deployment/axelar-node -n "$NAMESPACE"
else
    kubectl wait --for=condition=available --timeout=600s deployment/axelar-validator -n "$NAMESPACE"
fi

log "Deployment completed successfully!"

# Show status
log "Current status:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=axelar

# Show logs command
if [[ "$COMPONENT" == "node" ]]; then
    log "To view logs, run: kubectl logs -f deployment/axelar-node -n $NAMESPACE"
else
    log "To view logs, run:"
    log "  Validator: kubectl logs -f deployment/axelar-validator -c axelar-validator -n $NAMESPACE"
    log "  Vald: kubectl logs -f deployment/axelar-validator -c vald -n $NAMESPACE"
    log "  Tofnd: kubectl logs -f deployment/axelar-validator -c tofnd -n $NAMESPACE"
fi

# Show port forwarding commands
log "To access services locally:"
log "  RPC: kubectl port-forward svc/axelar-node-service 26657:26657 -n $NAMESPACE"
log "  API: kubectl port-forward svc/axelar-node-service 1317:1317 -n $NAMESPACE"
log "  Prometheus: kubectl port-forward svc/axelar-node-service 26660:26660 -n $NAMESPACE"
