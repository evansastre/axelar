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
REPO_URL=""
DRY_RUN=false
AUTO_DETECT=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Configure GitOps repository URLs in ArgoCD applications"
    echo ""
    echo "Options:"
    echo "  -r, --repo-url URL     Repository URL (e.g., https://github.com/user/repo)"
    echo "  -d, --dry-run          Show what would be changed without making changes"
    echo "  --no-auto-detect       Don't try to auto-detect repository URL from git"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Auto-detect repository URL from current git repo"
    echo "  $0"
    echo ""
    echo "  # Specify repository URL manually"
    echo "  $0 -r https://github.com/myuser/axelar-k8s-deployment"
    echo ""
    echo "  # Dry run to see what would be changed"
    echo "  $0 -d"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo-url)
            REPO_URL="$2"
            AUTO_DETECT=false
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-auto-detect)
            AUTO_DETECT=false
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

# Auto-detect repository URL if not provided
if [[ "$AUTO_DETECT" == "true" && -z "$REPO_URL" ]]; then
    log "Auto-detecting repository URL..."
    
    if git remote -v &> /dev/null; then
        ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$ORIGIN_URL" ]]; then
            # Convert SSH URL to HTTPS if needed
            if [[ "$ORIGIN_URL" =~ ^git@github.com: ]]; then
                REPO_URL=$(echo "$ORIGIN_URL" | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
            elif [[ "$ORIGIN_URL" =~ ^https://github.com/ ]]; then
                REPO_URL=$(echo "$ORIGIN_URL" | sed 's/\.git$//')
            else
                REPO_URL="$ORIGIN_URL"
            fi
            log "Detected repository URL: $REPO_URL"
        else
            warn "Could not detect repository URL from git remote"
        fi
    else
        warn "Not in a git repository or git not available"
    fi
fi

# Prompt for repository URL if still not set
if [[ -z "$REPO_URL" ]]; then
    echo
    echo "Please enter your repository URL:"
    echo "Examples:"
    echo "  https://github.com/yourusername/axelar-k8s-deployment"
    echo "  https://gitlab.com/yourusername/axelar-k8s-deployment"
    echo "  git@github.com:yourusername/axelar-k8s-deployment.git"
    echo
    read -p "Repository URL: " REPO_URL
    
    if [[ -z "$REPO_URL" ]]; then
        error "Repository URL is required"
    fi
fi

# Validate repository URL
if [[ ! "$REPO_URL" =~ ^https?:// && ! "$REPO_URL" =~ ^git@ ]]; then
    error "Invalid repository URL format: $REPO_URL"
fi

log "Configuring GitOps files with repository URL: $REPO_URL"

# Files to update
declare -a FILES=(
    "gitops/applications/axelar-project.yaml"
    "gitops/applications/axelar-operator.yaml"
    "gitops/applications/axelar-testnet.yaml"
    "gitops/applications/axelar-mainnet.yaml"
    "gitops/applications/axelar-applicationset.yaml"
    "gitops/environments/testnet/kustomization.yaml"
    "gitops/environments/mainnet/kustomization.yaml"
)

# Function to update file
update_file() {
    local file="$1"
    local repo_url="$2"
    
    if [[ ! -f "$file" ]]; then
        warn "File not found: $file"
        return
    fi
    
    log "Updating $file..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would update $file:"
        grep -n "YOUR_USERNAME" "$file" || true
        echo
    else
        # Create backup
        cp "$file" "$file.backup"
        
        # Update repository URLs
        sed -i.tmp "s|https://github.com/YOUR_USERNAME/axelar-k8s-deployment|$repo_url|g" "$file"
        sed -i.tmp "s|repo: https://github.com/YOUR_USERNAME/axelar-k8s-deployment|repo: $repo_url|g" "$file"
        
        # Clean up temporary file
        rm -f "$file.tmp"
        
        # Show what was changed
        if ! diff -q "$file.backup" "$file" > /dev/null; then
            debug "Changes made to $file"
        else
            debug "No changes needed in $file"
        fi
    fi
}

# Update all files
for file in "${FILES[@]}"; do
    update_file "$file" "$REPO_URL"
done

if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run completed. Use without -d flag to apply changes."
    exit 0
fi

# Update repository configuration
log "Updating repository configuration..."
cat > gitops/config/repository.yaml << EOF
# Repository Configuration for GitOps
# This file was auto-generated by configure-gitops-repo.sh

apiVersion: v1
kind: ConfigMap
metadata:
  name: gitops-config
  namespace: argocd
data:
  # Configured repository URL
  repository.url: "$REPO_URL"
  
  # Branch/revision to track
  repository.revision: "HEAD"
  
  # Configuration timestamp
  configured.at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  configured.by: "$(whoami)@$(hostname)"
EOF

# Verify changes
log "Verifying configuration..."
REMAINING=$(grep -r "YOUR_USERNAME" gitops/ 2>/dev/null | wc -l || echo "0")
if [[ "$REMAINING" -eq 0 ]]; then
    log "✅ All placeholder URLs have been updated"
else
    warn "⚠️  Found $REMAINING remaining placeholder URLs"
    grep -r "YOUR_USERNAME" gitops/ || true
fi

log "🎉 GitOps repository configuration completed!"
echo
log "Configuration Summary:"
log "  Repository URL: $REPO_URL"
log "  Files updated: ${#FILES[@]}"
log "  Backup files created: *.backup"
echo
log "Next steps:"
log "  1. Review the changes: git diff"
log "  2. Commit the changes: git add . && git commit -m 'Configure GitOps repository URLs'"
log "  3. Push to repository: git push"
log "  4. Deploy ArgoCD: ./scripts/deploy-argocd.sh"
echo
log "To restore original files if needed:"
log "  find gitops/ -name '*.backup' -exec sh -c 'mv \"\$1\" \"\${1%.backup}\"' _ {} \\;"
