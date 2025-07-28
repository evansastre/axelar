#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    error "minikube is not installed. Please install minikube first."
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed. Please install kubectl first."
fi

log "Starting minikube cluster for Axelar testing..."

# Check if minikube is running, start if not
if ! minikube status > /dev/null 2>&1; then
    log "Starting minikube..."
    minikube start \
        --cpus=4 \
        --memory=8192 \
        --disk-size=50g \
        --driver=docker
else
    log "Using existing minikube cluster"
fi

# Wait for minikube to be ready
log "Waiting for minikube to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Enable necessary addons
log "Enabling minikube addons..."
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Create test password
TEST_PASSWORD="testpassword123"

log "Deploying Axelar node to minikube..."

# Deploy using our script
./scripts/deploy.sh -n testnet -c node -k "$TEST_PASSWORD"

log "Waiting for node to be fully ready..."
sleep 30

# Check pod status
log "Checking pod status:"
kubectl get pods -n axelar-testnet -l app.kubernetes.io/name=axelar

# Check services
log "Checking services:"
kubectl get svc -n axelar-testnet

# Test connectivity
log "Testing node connectivity..."
kubectl port-forward svc/axelar-node-service 26657:26657 -n axelar-testnet &
PORT_FORWARD_PID=$!

# Wait for port forward to establish
sleep 5

# Test RPC endpoint
if curl -s http://localhost:26657/status > /dev/null; then
    log "✅ RPC endpoint is accessible"
else
    warn "❌ RPC endpoint is not accessible"
fi

# Kill port forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# Show logs
log "Recent logs from Axelar node:"
kubectl logs deployment/axelar-node -n axelar-testnet --tail=20

log "Local testing setup complete!"
log ""
log "Useful commands for testing:"
log "  View logs: kubectl logs -f deployment/axelar-node -n axelar-testnet"
log "  Port forward RPC: kubectl port-forward svc/axelar-node-service 26657:26657 -n axelar-testnet"
log "  Port forward API: kubectl port-forward svc/axelar-node-service 1317:1317 -n axelar-testnet"
log "  Port forward Prometheus: kubectl port-forward svc/axelar-node-service 26660:26660 -n axelar-testnet"
log "  Check status: curl http://localhost:26657/status"
log "  Check metrics: curl http://localhost:26660/metrics"
log ""
log "To clean up: minikube delete"
