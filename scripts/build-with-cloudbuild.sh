#!/bin/bash

# Cloud Build Helper Script for ADK Production Images
# This script triggers Cloud Build to build Docker images

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Function to build images using Cloud Build
build_with_cloud_build() {
    local project_id="$1"
    local region="$2"
    local dry_run="$3"
    
    print_step "Building Docker images using Google Cloud Build"
    
    if [ "$dry_run" = "true" ]; then
        print_info "🔍 DRY RUN: Would trigger Cloud Build for:"
        print_info "  - ADK Backend image"
        print_info "  - Ollama Proxy image"
        return 0
    fi
    
    # Change to project root directory
    local project_root="$(dirname "$SCRIPT_DIR")"
    cd "$project_root"
    
    # Generate a SHORT_SHA if not in git environment
    local short_sha
    if git rev-parse --git-dir > /dev/null 2>&1; then
        short_sha=$(git rev-parse --short=7 HEAD)
        print_info "Using git commit SHA: $short_sha"
    else
        short_sha=$(date +%s | tail -c 8)
        print_info "Generated timestamp-based SHA: $short_sha"
    fi
    
    print_step "Triggering Cloud Build for ADK Backend..."
    gcloud builds submit \
        --config=cloudbuild-adk.yaml \
        --project="$project_id" \
        --region="$region" \
        --substitutions="_SHORT_SHA=$short_sha" \
        . || {
        print_error "ADK Backend build failed"
        exit 1
    }
    
    print_success "ADK Backend build completed successfully"
    
    print_step "Triggering Cloud Build for Ollama Proxy..."
    gcloud builds submit \
        --config=cloudbuild-ollama.yaml \
        --project="$project_id" \
        --region="$region" \
        --substitutions="_SHORT_SHA=$short_sha" \
        . || {
        print_error "Ollama Proxy build failed"
        exit 1
    }
    
    print_success "Ollama Proxy build completed successfully"
    
    # Show final image URIs
    local registry_base="$region-docker.pkg.dev/$project_id/webui-adk-repo"
    print_info "Built images:"
    print_info "  - ADK Backend: $registry_base/adk-backend:latest"
    print_info "  - ADK Backend: $registry_base/adk-backend:$short_sha"
    print_info "  - Ollama Proxy: $registry_base/ollama-proxy:latest"
    print_info "  - Ollama Proxy: $registry_base/ollama-proxy:$short_sha"
    
    print_success "All Cloud Build jobs completed successfully"
}

# Check if called directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse arguments
    PROJECT_ID="$1"
    REGION="$2"
    DRY_RUN="$3"
    
    if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
        echo "Usage: $0 <project_id> <region> [dry_run]"
        echo "Example: $0 my-project us-central1 false"
        exit 1
    fi
    
    build_with_cloud_build "$PROJECT_ID" "$REGION" "$DRY_RUN"
fi
