#!/bin/bash

# Setup local git server for ArgoCD development
set -e

echo "Setting up local git server for ArgoCD..."

# Create a bare repository
REPO_DIR="/tmp/axelar-git-server"
rm -rf $REPO_DIR
mkdir -p $REPO_DIR
cd $REPO_DIR
git init --bare axelar.git

# Clone and push our local repository to the bare repo
cd /tmp
rm -rf axelar-local-clone
git clone /Users/evanshsl/repo/axelar/axelar-k8s-deployment axelar-local-clone
cd axelar-local-clone
git remote add local file://$REPO_DIR/axelar.git
git push local main

# Start a simple HTTP git server
echo "Starting git HTTP server on port 8090..."
cd $REPO_DIR
python3 -m http.server 8090 &
GIT_SERVER_PID=$!

echo "Git server started with PID: $GIT_SERVER_PID"
echo "Repository available at: http://localhost:8090/axelar.git"
echo "To stop the server, run: kill $GIT_SERVER_PID"

# Update ArgoCD repository secret
kubectl patch secret axelar-repository -n argocd -p '{"stringData":{"url":"http://host.docker.internal:8090/axelar.git"}}'

echo "ArgoCD repository secret updated to use local git server"
echo "Note: This is for development only!"
