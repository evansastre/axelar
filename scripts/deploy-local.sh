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

# Detect architecture
ARCH=$(uname -m)
log "Detected architecture: $ARCH"

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    log "Starting minikube..."
    minikube start --cpus=2 --memory=6144 --disk-size=30g --driver=docker
else
    log "Using existing minikube cluster"
fi

# Wait for minikube to be ready
log "Waiting for minikube to be ready..."
kubectl wait --for=condition=Ready node/minikube --timeout=300s

# Enable required addons
log "Enabling minikube addons..."
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Create namespace
log "Creating namespace axelar-testnet..."
kubectl create namespace axelar-testnet --dry-run=client -o yaml | kubectl apply -f -

# Create secrets
log "Creating secrets..."
kubectl create secret generic axelar-secrets \
  --from-literal=keyring-password=testpassword123 \
  --namespace=axelar-testnet \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy based on architecture
if [[ "$ARCH" == "arm64" ]]; then
    warn "ARM64 architecture detected - using mock Axelar image for compatibility"
    
    # Build and load mock image if it doesn't exist
    if ! docker image inspect mock-axelar:latest > /dev/null 2>&1; then
        log "Building mock Axelar image..."
        docker build -f Dockerfile.mock -t mock-axelar:latest .
    fi
    
    log "Loading mock image into minikube..."
    minikube image load mock-axelar:latest
    
    log "Deploying ARM64-compatible Axelar node..."
    kubectl apply -f mock-axelar-deployment.yaml
    
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/mock-axelar-node -n axelar-testnet
    
else
    log "AMD64 architecture detected - using official Axelar image"
    log "Deploying official Axelar node..."
    kubectl apply -k k8s/testnet/
    
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/axelar-node -n axelar-testnet
fi

# Show deployment status
log "Deployment completed successfully!"
echo
log "Current status:"
kubectl get pods -n axelar-testnet
echo
log "Services:"
kubectl get svc -n axelar-testnet
echo

# Test endpoints
log "Testing endpoints..."
if [[ "$ARCH" == "arm64" ]]; then
    POD_NAME=$(kubectl get pods -n axelar-testnet -l app.kubernetes.io/name=axelar -o jsonpath='{.items[0].metadata.name}')
    SERVICE_NAME="axelar-node-service"
else
    POD_NAME=$(kubectl get pods -n axelar-testnet -l app.kubernetes.io/name=axelar -o jsonpath='{.items[0].metadata.name}')
    SERVICE_NAME="axelar-node-service"
fi

# Test health endpoint
log "Testing health endpoint..."
kubectl exec -n axelar-testnet $POD_NAME -- python3 -c "
import urllib.request
try:
    response = urllib.request.urlopen('http://localhost:26660/health')
    print('✅ Health endpoint: WORKING')
except:
    print('❌ Health endpoint: FAILED')
" 2>/dev/null || echo "❌ Health endpoint: FAILED"

# Test metrics endpoint
log "Testing metrics endpoint..."
kubectl exec -n axelar-testnet $POD_NAME -- python3 -c "
import urllib.request
try:
    response = urllib.request.urlopen('http://localhost:26660/metrics')
    content = response.read().decode('utf-8')
    if 'tendermint_consensus_height' in content:
        print('✅ Metrics endpoint: WORKING')
    else:
        print('❌ Metrics endpoint: Invalid content')
except:
    print('❌ Metrics endpoint: FAILED')
" 2>/dev/null || echo "❌ Metrics endpoint: FAILED"

echo
log "🎉 Local deployment test completed!"
echo
log "Useful commands:"
log "  View logs: kubectl logs -f deployment/$POD_NAME -n axelar-testnet"
log "  Port forward metrics: kubectl port-forward svc/$SERVICE_NAME 26660:26660 -n axelar-testnet"
log "  Port forward RPC: kubectl port-forward svc/$SERVICE_NAME 26657:26657 -n axelar-testnet"
log "  Test metrics: curl http://localhost:26660/metrics"
log "  Test health: curl http://localhost:26660/health"
echo
log "To clean up: kubectl delete namespace axelar-testnet"
