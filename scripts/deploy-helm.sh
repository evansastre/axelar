#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEPLOYMENT_TYPE="node"
NETWORK="testnet"
RELEASE_NAME=""
NAMESPACE=""
KEYRING_PASSWORD=""
TOFND_PASSWORD=""
VALUES_FILE=""
DRY_RUN=false
UPGRADE=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Axelar node or validator using Helm"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE            Deployment type (node|validator) [default: node]"
    echo "  -n, --network NETWORK      Network (testnet|mainnet) [default: testnet]"
    echo "  -r, --release RELEASE      Helm release name [default: axelar-{type}-{network}]"
    echo "  -s, --namespace NAMESPACE  Kubernetes namespace [default: axelar-{network}]"
    echo "  -k, --keyring-password     Keyring password (required)"
    echo "  -p, --tofnd-password       Tofnd password (required for validator)"
    echo "  -f, --values-file FILE     Custom values file"
    echo "  -u, --upgrade              Upgrade existing release"
    echo "  -d, --dry-run              Perform a dry run"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy testnet node"
    echo "  $0 -t node -n testnet -k mypassword"
    echo ""
    echo "  # Deploy validator with custom values"
    echo "  $0 -t validator -n testnet -k mypassword -p mytofndpassword -f custom-values.yaml"
    echo ""
    echo "  # Upgrade existing deployment"
    echo "  $0 -t node -n testnet -k mypassword -u"
    echo ""
    echo "  # Dry run deployment"
    echo "  $0 -t validator -n testnet -k mypassword -p mytofndpassword -d"
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

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            DEPLOYMENT_TYPE="$2"
            shift 2
            ;;
        -n|--network)
            NETWORK="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -s|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -k|--keyring-password)
            KEYRING_PASSWORD="$2"
            shift 2
            ;;
        -p|--tofnd-password)
            TOFND_PASSWORD="$2"
            shift 2
            ;;
        -f|--values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        -u|--upgrade)
            UPGRADE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
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

# Validation
if [[ "$DEPLOYMENT_TYPE" != "node" && "$DEPLOYMENT_TYPE" != "validator" ]]; then
    error "Deployment type must be 'node' or 'validator'"
fi

if [[ "$NETWORK" != "testnet" && "$NETWORK" != "mainnet" ]]; then
    error "Network must be 'testnet' or 'mainnet'"
fi

if [[ -z "$KEYRING_PASSWORD" ]]; then
    error "Keyring password is required"
fi

if [[ "$DEPLOYMENT_TYPE" == "validator" && -z "$TOFND_PASSWORD" ]]; then
    error "Tofnd password is required for validator deployment"
fi

if [[ ${#KEYRING_PASSWORD} -lt 8 ]]; then
    error "Keyring password must be at least 8 characters long"
fi

# Set defaults
if [[ -z "$RELEASE_NAME" ]]; then
    RELEASE_NAME="axelar-${DEPLOYMENT_TYPE}-${NETWORK}"
fi

if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE="axelar-${NETWORK}"
fi

if [[ -z "$VALUES_FILE" ]]; then
    if [[ "$DEPLOYMENT_TYPE" == "validator" ]]; then
        VALUES_FILE="helm/axelar-node/values-validator.yaml"
    else
        VALUES_FILE="helm/axelar-node/values-testnet-node.yaml"
    fi
fi

log "Deploying Axelar $DEPLOYMENT_TYPE to $NETWORK network"
debug "Release name: $RELEASE_NAME"
debug "Namespace: $NAMESPACE"
debug "Values file: $VALUES_FILE"

# Check if helm is available
if ! command -v helm &> /dev/null; then
    error "Helm is not installed or not in PATH"
fi

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

# Prepare Helm command
HELM_CMD="helm"
if [[ "$UPGRADE" == "true" ]]; then
    HELM_CMD="$HELM_CMD upgrade"
else
    HELM_CMD="$HELM_CMD install"
fi

HELM_CMD="$HELM_CMD $RELEASE_NAME helm/axelar-node/"
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --values $VALUES_FILE"
HELM_CMD="$HELM_CMD --set deploymentType=$DEPLOYMENT_TYPE"
HELM_CMD="$HELM_CMD --set network.name=$NETWORK"
HELM_CMD="$HELM_CMD --set secrets.keyringPassword=$KEYRING_PASSWORD"

if [[ "$DEPLOYMENT_TYPE" == "validator" ]]; then
    HELM_CMD="$HELM_CMD --set secrets.tofndPassword=$TOFND_PASSWORD"
    HELM_CMD="$HELM_CMD --set validator.enabled=true"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    HELM_CMD="$HELM_CMD --dry-run --debug"
fi

# Execute Helm command
log "Executing Helm deployment..."
debug "Command: $HELM_CMD"

eval $HELM_CMD

if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run completed successfully!"
    exit 0
fi

# Wait for deployment to be ready
log "Waiting for deployment to be ready..."
if [[ "$DEPLOYMENT_TYPE" == "validator" ]]; then
    kubectl wait --for=condition=available --timeout=600s deployment/${RELEASE_NAME} -n "$NAMESPACE"
else
    kubectl wait --for=condition=available --timeout=600s deployment/${RELEASE_NAME} -n "$NAMESPACE"
fi

log "Deployment completed successfully!"

# Show status
log "Current status:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

# Show services
log "Services:"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

# Show useful commands
log "Useful commands:"
log "  View logs: kubectl logs -f deployment/${RELEASE_NAME} -n $NAMESPACE"
if [[ "$DEPLOYMENT_TYPE" == "validator" ]]; then
    log "  View vald logs: kubectl logs -f deployment/${RELEASE_NAME} -c vald -n $NAMESPACE"
    log "  View tofnd logs: kubectl logs -f deployment/${RELEASE_NAME} -c tofnd -n $NAMESPACE"
fi
log "  Port forward RPC: kubectl port-forward svc/${RELEASE_NAME}-service 26657:26657 -n $NAMESPACE"
log "  Port forward API: kubectl port-forward svc/${RELEASE_NAME}-service 1317:1317 -n $NAMESPACE"
log "  Port forward Prometheus: kubectl port-forward svc/${RELEASE_NAME}-service 26660:26660 -n $NAMESPACE"

# Show Helm status
log "Helm release status:"
helm status "$RELEASE_NAME" -n "$NAMESPACE"

log "🎉 Deployment completed successfully!"
