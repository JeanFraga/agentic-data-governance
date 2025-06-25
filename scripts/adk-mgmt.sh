#!/bin/bash

# Unified Agentic Data Governance Management Script
# This script consolidates deployment, testing, and management functionality

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Script version
VERSION="1.0.0"

# Default configuration
DEFAULT_NAMESPACE="webui-adk-local"
DEFAULT_RELEASE_NAME="webui-adk-local"
DEFAULT_CHART_DIR="./webui-adk-chart"
DEFAULT_VALUES_FILE="values-local.yaml"

# Show help
show_script_help() {
    print_header "ADK Management Script v$VERSION"
    echo ""
    echo "USAGE:"
    echo "  ./adk-mgmt.sh <command> [options]"
    echo ""
    echo "COMMANDS:"
    echo ""
    echo "  📋 Environment & Setup:"
    echo "    env check              Check environment variables"
    echo "    env setup              Interactive environment setup"
    echo "    domain setup           Configure custom domain"
    echo "    dns setup              Set up DNS configuration"
    echo "    oauth setup            Configure OAuth settings"
    echo ""
    echo "  🚀 Deployment:"
    echo "    build [images]         Build production Docker images using Cloud Build"
    echo "    build cloudbuild       Build using Google Cloud Build (explicit)"
    echo "    build legacy           Build using local Docker (deprecated)"
    echo "    deploy local           Deploy to local/development environment"
    echo "    deploy production      Deploy to GKE production (includes Cloud Build)"
    echo "    deploy quick           Quick deployment with auto-setup"
    echo "    deploy quota-limited   Deploy with minimal resources"
    echo "    destroy local          Destroy local deployment"
    echo "    destroy production     Destroy production deployment"
    echo ""
    echo "  🧪 Testing & Validation:"
    echo "    test all               Run all tests"
    echo "    test auth              Test authentication features"
    echo "    test dns               Test DNS configuration"
    echo "    test domain            Test domain setup"
    echo "    test connectivity      Test network connectivity"
    echo ""
    echo "  🔧 Backend Management:"
    echo "    backend start          Start ADK backend services"
    echo "    backend stop           Stop ADK backend services"
    echo "    backend config         Configure backend for Ollama"
    echo "    backend test           Test backend integration"
    echo "    stack start            Start full Ollama+ADK+OpenWebUI stack"
    echo "    stack stop             Stop full stack"
    echo ""
    echo "  📊 Status & Info:"
    echo "    status                 Show deployment status"
    echo "    logs [service]         Show logs for service"
    echo "    info                   Show connection information"
    echo "    resources              Show resource usage"
    echo ""
    echo "  🔧 Management:"
    echo "    restart [service]      Restart service(s)"
    echo "    scale <replicas>       Scale deployment"
    echo "    upgrade                Upgrade deployment"
    echo "    cleanup                Clean up resources"
    echo ""
    echo "  🛠️ Troubleshooting:"
    echo "    fix oauth              Fix OAuth redirect issues"
    echo "    fix quota              Help with quota issues"
    echo "    debug                  Debug deployment issues"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --namespace <name>   Kubernetes namespace (default: $DEFAULT_NAMESPACE)"
    echo "  -r, --release <name>     Helm release name (default: $DEFAULT_RELEASE_NAME)"
    echo "  -f, --values <file>      Values file (default: $DEFAULT_VALUES_FILE)"
    echo "  -v, --verbose            Verbose output"
    echo "  --dry-run                Show what would be done without executing"
    echo "  -h, --help               Show this help"
    echo ""
    echo "EXAMPLES:"
    echo "  ./adk-mgmt.sh env check"
    echo "  ./adk-mgmt.sh build images --dry-run"
    echo "  ./adk-mgmt.sh deploy local"
    echo "  ./adk-mgmt.sh deploy production"
    echo "  ./adk-mgmt.sh test all"
    echo "  ./adk-mgmt.sh status"
    echo "  ./adk-mgmt.sh logs adk-backend"
    echo ""
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    SUBCOMMAND=""
    NAMESPACE="$DEFAULT_NAMESPACE"
    RELEASE_NAME="$DEFAULT_RELEASE_NAME"
    VALUES_FILE="$DEFAULT_VALUES_FILE"
    VERBOSE=false
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -r|--release)
                RELEASE_NAME="$2"
                shift 2
                ;;
            -f|--values)
                VALUES_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_script_help
                exit 0
                ;;
            *)
                if [ -z "$COMMAND" ]; then
                    COMMAND="$1"
                elif [ -z "$SUBCOMMAND" ]; then
                    SUBCOMMAND="$1"
                fi
                shift
                ;;
        esac
    done
}

# Environment functions
cmd_env() {
    case "$SUBCOMMAND" in
        check)
            env_check
            ;;
        setup)
            env_setup
            ;;
        *)
            print_error "Unknown env command: $SUBCOMMAND"
            echo "Available: check, setup"
            exit 1
            ;;
    esac
}

env_check() {
    print_step "Checking environment configuration"
    
    check_env_file ".env"
    load_env ".env"
    
    # Define required variables
    local required_vars=(
        "OAUTH_CLIENT_ID"
        "OAUTH_CLIENT_SECRET" 
        "GCP_PROJECT_ID"
        "ADMIN_EMAIL"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        else
            if [[ $var == *"SECRET"* ]] || [[ $var == *"KEY"* ]]; then
                print_success "$var is set (***masked***)"
            else
                print_success "$var is set: ${!var}"
            fi
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required variables: ${missing_vars[*]}"
        echo ""
        echo "Please configure these in your .env file"
        exit 1
    fi
    
    print_success "Environment configuration is valid"
}

env_setup() {
    print_step "Interactive environment setup"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_success "Created .env from .env.example"
        else
            print_error ".env.example not found"
            exit 1
        fi
    fi
    
    print_info "Please edit .env file with your configuration"
    print_info "Required variables:"
    echo "  - OAUTH_CLIENT_ID (Google OAuth Client ID)"
    echo "  - OAUTH_CLIENT_SECRET (Google OAuth Client Secret)"
    echo "  - GCP_PROJECT_ID (Google Cloud Project ID)"
    echo "  - ADMIN_EMAIL (Admin email address)"
    
    if confirm_action "Open .env file for editing now?"; then
        ${EDITOR:-nano} .env
    fi
    
    print_step "Validating configuration..."
    env_check
}

# Domain functions
cmd_domain() {
    case "$SUBCOMMAND" in
        setup)
            domain_setup
            ;;
        *)
            print_error "Unknown domain command: $SUBCOMMAND"
            echo "Available: setup"
            exit 1
            ;;
    esac
}

domain_setup() {
    print_step "Domain configuration setup"
    
    if [ ! -f "terraform/terraform.tfvars.example" ]; then
        print_error "terraform.tfvars.example not found"
        exit 1
    fi
    
    if [ ! -f "terraform/terraform.tfvars" ]; then
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        print_success "Created terraform.tfvars from example"
    fi
    
    print_info "Configure your domain settings in terraform/terraform.tfvars"
    
    if confirm_action "Open terraform.tfvars for editing now?"; then
        ${EDITOR:-nano} terraform/terraform.tfvars
    fi
}

# DNS functions  
cmd_dns() {
    case "$SUBCOMMAND" in
        setup)
            dns_setup
            ;;
        *)
            print_error "Unknown dns command: $SUBCOMMAND"
            echo "Available: setup"
            exit 1
            ;;
    esac
}

dns_setup() {
    print_step "DNS setup"
    print_info "This will create Google Cloud DNS zone and configure records"
    
    check_prerequisites "gcloud" "terraform"
    
    if confirm_action "Continue with DNS setup?"; then
        cd terraform
        terraform init
        terraform plan
        if confirm_action "Apply Terraform changes?"; then
            terraform apply
        fi
        cd ..
    fi
}

# OAuth functions
cmd_oauth() {
    case "$SUBCOMMAND" in
        setup)
            oauth_setup
            ;;
        *)
            print_error "Unknown oauth command: $SUBCOMMAND"
            echo "Available: setup"
            exit 1
            ;;
    esac
}

oauth_setup() {
    print_step "OAuth configuration setup"
    
    print_info "OAuth 2.0 Setup Instructions:"
    echo ""
    echo "1. Go to Google Cloud Console"
    echo "2. Navigate to APIs & Services > Credentials"
    echo "3. Create OAuth 2.0 Client ID"
    echo "4. Add redirect URIs:"
    echo "   - http://localhost:30080/oauth/oidc/callback"
    echo "   - https://your-domain.com/oauth/oidc/callback"
    echo ""
    
    # Show specific configuration for current setup
    if [ -f "terraform/terraform.tfvars.production" ]; then
        local app_host=$(grep '^app_host' terraform/terraform.tfvars.production | cut -d'"' -f2 2>/dev/null || echo "")
        if [ -n "$app_host" ]; then
            echo "🔧 Current Production Configuration:"
            echo "   Required redirect URI: https://$app_host/oauth/oidc/callback"
            echo ""
            echo "   Direct link to update OAuth client:"
            echo "   https://console.cloud.google.com/apis/credentials/oauthclient/112698224261-ktmjfk2fnhkj0ksjelcuo2gn23jqk8fi.apps.googleusercontent.com?project=agenticds-hackathon-54443"
            echo ""
        fi
    fi
    
    if confirm_action "Have you configured OAuth in Google Cloud Console?"; then
        env_check
        print_success "OAuth setup complete"
    else
        print_warning "Please configure OAuth first, then run this command again"
    fi
}

# Deployment functions
cmd_deploy() {
    case "$SUBCOMMAND" in
        local)
            deploy_local
            ;;
        production)
            deploy_production
            ;;
        quick)
            deploy_quick
            ;;
        quota-limited)
            deploy_quota_limited
            ;;
        *)
            print_error "Unknown deploy command: $SUBCOMMAND"
            echo "Available: local, production, quick, quota-limited"
            exit 1
            ;;
    esac
}

deploy_local() {
    print_step "Deploying to local/development environment using Terraform"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN MODE - No changes will be applied"
    fi
    
    check_prerequisites "terraform" "kubectl" "helm" "docker"
    
    # Build required Docker images for local deployment
    if [ "$DRY_RUN" != "true" ]; then
        print_step "Building Docker images for local deployment..."
        build_local_images
    else
        print_info "🔍 DRY RUN: Would build Docker images for local deployment"
    fi
    
    # Ensure we're using local Docker Desktop context
    print_step "Checking Kubernetes context..."
    local current_context=$(kubectl config current-context)
    if [ "$current_context" != "docker-desktop" ]; then
        print_warning "Current context is '$current_context'. Switching to 'docker-desktop'..."
        kubectl config use-context docker-desktop
    fi
    
    # Navigate to unified terraform directory
    local terraform_dir="$(dirname "$SCRIPT_DIR")/terraform"
    if [ ! -d "$terraform_dir" ]; then
        print_error "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    print_step "Configuring Terraform backend for local deployment..."
    # Use local backend configuration
    if [ -f "backend-local.tf.template" ]; then
        cp backend-local.tf.template backend.tf
    else
        print_warning "Local backend configuration not found, using default"
    fi
    
    print_step "Initializing Terraform for local deployment..."
    terraform init -reconfigure
    
    print_step "Planning local deployment..."
    terraform plan -var-file="terraform.tfvars.local"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would apply local deployment with terraform.tfvars.local"
        print_success "Dry run completed - no changes applied"
        return 0
    fi
    
    print_step "Applying local deployment..."
    terraform apply -var-file="terraform.tfvars.local" -auto-approve
    
    print_success "Local deployment completed successfully"
    
    # Show connection information
    echo ""
    print_header "Connection Information"
    echo "Environment: local"
    echo "Namespace:   adk-local"
    echo "Release:     adk-local"
    echo "Context:     docker-desktop"
    echo "State file:  terraform-local.tfstate"
    echo ""
    echo "To access the application:"
    echo "  Direct access: http://localhost:30080 (NodePort)"
    echo "  Port-forward:  kubectl port-forward -n adk-local svc/adk-local-open-webui 8080:80"
    echo "                 Then open: http://localhost:8080"
    echo ""
    echo "To check status:"
    echo "  kubectl get pods -n adk-local"
    echo "  helm list -n adk-local"
}

deploy_production() {
    print_step "Deploying to GKE production environment using Terraform"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN MODE - No changes will be applied"
    fi
    
    check_prerequisites "terraform" "kubectl" "gcloud"
    check_kubernetes
    env_check
    
    # Navigate to unified terraform directory
    local terraform_dir="$(dirname "$SCRIPT_DIR")/terraform"
    if [ ! -d "$terraform_dir" ]; then
        print_error "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    # Check for production tfvars file
    if [ ! -f "terraform.tfvars" ] && [ ! -f "terraform.tfvars.production" ]; then
        print_error "Production tfvars file not found. Expected 'terraform.tfvars' or 'terraform.tfvars.production'"
        exit 1
    fi
    
    # Use production tfvars file
    local prod_tfvars="terraform.tfvars"
    if [ -f "terraform.tfvars.production" ]; then
        prod_tfvars="terraform.tfvars.production"
    fi
    
    print_warning "This will deploy to production environment using: $prod_tfvars"
    if ! confirm_action "Continue with production deployment?"; then
        exit 0
    fi
    
    # Build production Docker images with x86 architecture
    build_production_images
    
    # Return to terraform directory
    cd "$terraform_dir"
    
    print_step "Configuring Terraform backend for production deployment..."
    # Use production backend configuration
    if [ -f "backend-production.tf.template" ]; then
        cp backend-production.tf.template backend.tf
    else
        print_warning "Production backend configuration not found, using default"
    fi
    
    print_step "Initializing Terraform for production deployment..."
    terraform init -reconfigure
    
    print_step "Planning production deployment..."
    terraform plan -var-file="$prod_tfvars"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would apply production deployment with $prod_tfvars"
        print_success "Dry run completed - no changes applied"
        return 0
    fi
    
    print_step "Applying production deployment..."
    terraform apply -var-file="$prod_tfvars" -auto-approve
    
    print_success "Production deployment completed successfully"
    
    # Show connection information
    echo ""
    print_header "Production Deployment Information"
    echo "Environment: production"
    echo "State file:  terraform-production.tfstate"
    echo "Values file: $prod_tfvars"
    echo ""
    echo "To check status:"
    echo "  kubectl get pods"
    echo "  helm list"
    echo ""
    echo "To get outputs:"
    echo "  terraform output"
}

# Local Docker build functions for development deployment
build_local_images() {
    print_step "Building Docker images for local deployment"
    
    local project_dir="$(dirname "$SCRIPT_DIR")"
    local adk_backend_dir="$project_dir/adk-backend"
    
    if [ ! -d "$adk_backend_dir" ]; then
        print_error "ADK backend directory not found: $adk_backend_dir"
        exit 1
    fi
    
    print_info "Building ADK backend image locally..."
    cd "$adk_backend_dir"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would build adk-backend:local image"
    else
        # Build ADK backend image with local tag
        docker build -t adk-backend:local .
        if [ $? -eq 0 ]; then
            print_success "Successfully built adk-backend:local"
        else
            print_error "Failed to build adk-backend:local"
            exit 1
        fi
    fi
    
    # Check if ollama-proxy needs to be built (look for existing Dockerfile)
    cd "$project_dir"
    if [ -f "ollama-proxy/Dockerfile" ] || [ -f "adk-backend/Dockerfile.ollama-proxy" ]; then
        print_info "Building Ollama proxy image locally..."
        if [ "$DRY_RUN" = "true" ]; then
            print_info "🔍 DRY RUN: Would build ollama-proxy:local image"
        else
            # Build from adk-backend directory if Dockerfile.ollama-proxy exists there
            if [ -f "$adk_backend_dir/Dockerfile.ollama-proxy" ]; then
                cd "$adk_backend_dir"
                docker build -f Dockerfile.ollama-proxy -t ollama-proxy:local .
            elif [ -f "ollama-proxy/Dockerfile" ]; then
                cd "ollama-proxy"
                docker build -t ollama-proxy:local .
            fi
            
            if [ $? -eq 0 ]; then
                print_success "Successfully built ollama-proxy:local"
            else
                print_error "Failed to build ollama-proxy:local"
                exit 1
            fi
        fi
    else
        print_warning "No Ollama proxy Dockerfile found. Using OpenWebUI's built-in Ollama connection."
        print_info "Note: You may need to create ollama-proxy image or configure alternative connection method."
    fi
    
    cd "$project_dir"
    print_success "Local image build completed"
}

# Cloud Build functions for production deployment
build_production_images() {
    print_step "Building Docker images using Google Cloud Build"
    
    local project_dir="$(dirname "$SCRIPT_DIR")"
    local terraform_dir="$project_dir/terraform"
    
    # Extract project ID and region from terraform vars
    local prod_tfvars="terraform.tfvars"
    if [ -f "$terraform_dir/terraform.tfvars.production" ]; then
        prod_tfvars="terraform.tfvars.production"
    fi
    
    local gcp_project_id=$(grep '^gcp_project_id' "$terraform_dir/$prod_tfvars" | cut -d'"' -f2)
    local gcp_region=$(grep '^gcp_region' "$terraform_dir/$prod_tfvars" | cut -d'"' -f2)
    
    if [ -z "$gcp_project_id" ] || [ -z "$gcp_region" ]; then
        print_error "Could not extract GCP project ID or region from $prod_tfvars"
        exit 1
    fi
    
    print_info "Using Cloud Build for project: $gcp_project_id in region: $gcp_region"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would trigger Cloud Build for production images"
        source "$SCRIPT_DIR/build-with-cloudbuild.sh"
        build_with_cloud_build "$gcp_project_id" "$gcp_region" "true"
        return 0
    fi
    
    # Use the Cloud Build helper script
    source "$SCRIPT_DIR/build-with-cloudbuild.sh"
    build_with_cloud_build "$gcp_project_id" "$gcp_region" "false"
}

# Legacy Docker build function (deprecated)
build_production_images_legacy() {
    print_warning "DEPRECATED: Using legacy local Docker build. Consider using Cloud Build instead."
    print_step "Building Docker images locally for x86 architecture"
    
    local project_dir="$(dirname "$SCRIPT_DIR")"
    local adk_backend_dir="$project_dir/adk-backend"
    
    if [ ! -d "$adk_backend_dir" ]; then
        print_error "ADK backend directory not found: $adk_backend_dir"
        exit 1
    fi
    
    cd "$adk_backend_dir"
    
    # Extract project ID and region from terraform vars
    local terraform_dir="$project_dir/terraform"
    local prod_tfvars="terraform.tfvars"
    if [ -f "$terraform_dir/terraform.tfvars.production" ]; then
        prod_tfvars="terraform.tfvars.production"
    fi
    
    local gcp_project_id=$(grep '^gcp_project_id' "$terraform_dir/$prod_tfvars" | cut -d'"' -f2)
    local gcp_region=$(grep '^gcp_region' "$terraform_dir/$prod_tfvars" | cut -d'"' -f2)
    
    if [ -z "$gcp_project_id" ] || [ -z "$gcp_region" ]; then
        print_error "Could not extract GCP project ID or region from $prod_tfvars"
        exit 1
    fi
    
    local registry_base="$gcp_region-docker.pkg.dev/$gcp_project_id/webui-adk-repo"
    local adk_image="$registry_base/adk-backend:latest"
    local ollama_image="$registry_base/ollama-proxy:latest"
    
    print_info "Registry: $registry_base"
    print_info "Building images for project: $gcp_project_id"
    
    # Configure Docker for multi-platform builds
    print_step "Setting up Docker buildx for multi-platform builds"
    if ! docker buildx inspect multiplatform > /dev/null 2>&1; then
        print_info "Creating multiplatform builder..."
        docker buildx create --name multiplatform --platform linux/amd64,linux/arm64 --use
    else
        print_info "Using existing multiplatform builder..."
        docker buildx use multiplatform
    fi
    
    # Authenticate with Google Cloud Artifact Registry
    print_step "Authenticating with Google Cloud Artifact Registry"
    gcloud auth configure-docker "$gcp_region-docker.pkg.dev" --quiet
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would build and push the following images:"
        print_info "  - $adk_image"
        print_info "  - $ollama_image"
        return 0
    fi
    
    # Build and push ADK backend image
    print_step "Building and pushing ADK backend image..."
    print_info "Building: $adk_image"
    docker buildx build \
        --platform linux/amd64 \
        --tag "$adk_image" \
        --push \
        --file Dockerfile \
        .
    
    # Build and push Ollama proxy image
    print_step "Building and pushing Ollama proxy image..."
    print_info "Building: $ollama_image"
    docker buildx build \
        --platform linux/amd64 \
        --tag "$ollama_image" \
        --push \
        --file Dockerfile.ollama-proxy \
        .
    
    print_success "Successfully built and pushed production images"
    print_info "ADK Backend: $adk_image"
    print_info "Ollama Proxy: $ollama_image"
}

# Build command function
cmd_build() {
    case "$SUBCOMMAND" in
        images)
            build_production_images
            ;;
        legacy)
            build_production_images_legacy
            ;;
        cloudbuild)
            build_production_images
            ;;
        *)
            if [ -z "$SUBCOMMAND" ]; then
                # Default to Cloud Build
                build_production_images
            else
                print_error "Unknown build command: $SUBCOMMAND"
                echo "Available options:"
                echo "  images     - Build using Cloud Build (default)"
                echo "  cloudbuild - Build using Cloud Build (explicit)"
                echo "  legacy     - Build using local Docker (deprecated)"
                exit 1
            fi
            ;;
    esac
}

deploy_quick() {
    print_step "Quick deployment with auto-setup"
    
    # Quick environment check
    if [ ! -f ".env" ]; then
        env_setup
    else
        env_check
    fi
    
    # Deploy locally
    deploy_local
    
    print_success "Quick deployment completed"
}

deploy_quota_limited() {
    print_step "Deploying with quota-limited configuration"
    
    check_prerequisites "helm" "kubectl"
    check_kubernetes
    env_check
    
    load_env ".env"
    
    # Use quota-limited values
    local quota_values="$DEFAULT_CHART_DIR/values-quota-limited.yaml"
    if [ ! -f "$quota_values" ]; then
        print_warning "Quota-limited values file not found, using default with reduced resources"
        quota_values="$DEFAULT_CHART_DIR/$VALUES_FILE"
    fi
    
    local temp_values="/tmp/adk-quota-values.yaml"
    envsubst < "$quota_values" > "$temp_values"
    
    helm upgrade --install "$RELEASE_NAME" "$DEFAULT_CHART_DIR" \
        -f "$temp_values" \
        -n "$NAMESPACE" \
        --create-namespace \
        --wait
    
    rm -f "$temp_values"
    
    print_success "Quota-limited deployment completed"
    show_connection_info
}

# Destroy functions
cmd_destroy() {
    case "$SUBCOMMAND" in
        local)
            destroy_local
            ;;
        production)
            destroy_production
            ;;
        *)
            print_error "Unknown destroy command: $SUBCOMMAND"
            echo "Available: local, production"
            exit 1
            ;;
    esac
}

destroy_local() {
    print_step "Destroying local deployment"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN MODE - No resources will be destroyed"
    fi
    
    check_prerequisites "terraform" "kubectl"
    
    # Ensure we're using local Docker Desktop context
    local current_context=$(kubectl config current-context)
    if [ "$current_context" != "docker-desktop" ]; then
        print_warning "Current context is '$current_context'. Switching to 'docker-desktop'..."
        kubectl config use-context docker-desktop
    fi
    
    # Navigate to unified terraform directory
    local terraform_dir="$(dirname "$SCRIPT_DIR")/terraform"
    if [ ! -d "$terraform_dir" ]; then
        print_error "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    print_step "Configuring Terraform backend for local deployment..."
    # Use local backend configuration
    if [ -f "backend-local.tf.template" ]; then
        cp backend-local.tf.template backend.tf
    else
        print_warning "Local backend configuration not found, using default"
    fi
    
    print_step "Initializing Terraform for local deployment..."
    terraform init -reconfigure
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would destroy local deployment with terraform.tfvars.local"
        terraform plan -destroy -var-file="terraform.tfvars.local"
        print_success "Dry run completed - no resources destroyed"
        return 0
    fi
    
    print_step "Destroying local Terraform deployment..."
    terraform destroy -var-file="terraform.tfvars.local" -auto-approve
    
    print_success "Local deployment destroyed successfully"
    print_info "Local state file 'terraform-local.tfstate' preserved for potential restore"
}

destroy_production() {
    print_step "Destroying production deployment"
    print_warning "This will destroy ALL production resources including the GKE cluster!"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN MODE - No resources will be destroyed"
    else
        read -p "Are you absolutely sure? Type 'destroy-production' to confirm: " confirmation
        if [ "$confirmation" != "destroy-production" ]; then
            print_error "Confirmation failed. Aborting."
            exit 1
        fi
    fi
    
    check_prerequisites "terraform" "gcloud"
    
    # Navigate to unified terraform directory
    local terraform_dir="$(dirname "$SCRIPT_DIR")/terraform"
    if [ ! -d "$terraform_dir" ]; then
        print_error "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    # Check for production tfvars file
    local prod_tfvars="terraform.tfvars"
    if [ -f "terraform.tfvars.production" ]; then
        prod_tfvars="terraform.tfvars.production"
    fi
    
    print_step "Configuring Terraform backend for production deployment..."
    # Use production backend configuration
    if [ -f "backend-production.tf.template" ]; then
        cp backend-production.tf.template backend.tf
    else
        print_warning "Production backend configuration not found, using default"
    fi
    
    print_step "Initializing Terraform for production deployment..."
    terraform init -reconfigure
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "🔍 DRY RUN: Would destroy production deployment with $prod_tfvars"
        terraform plan -destroy -var-file="$prod_tfvars"
        print_success "Dry run completed - no resources destroyed"
        return 0
    fi
    
    print_step "Destroying production Terraform deployment..."
    terraform destroy -var-file="$prod_tfvars"
    
    print_success "Production deployment destroyed"
    print_info "Production state file 'terraform-production.tfstate' preserved for potential restore"
}

# Testing functions
cmd_test() {
    case "$SUBCOMMAND" in
        all)
            test_all
            ;;
        auth)
            test_auth
            ;;
        dns)
            test_dns
            ;;
        domain)
            test_domain
            ;;
        connectivity)
            test_connectivity
            ;;
        *)
            print_error "Unknown test command: $SUBCOMMAND"
            echo "Available: all, auth, dns, domain, connectivity"
            exit 1
            ;;
    esac
}

test_all() {
    print_step "Running comprehensive test suite"
    
    print_info "Testing environment..."
    env_check
    
    print_info "Testing connectivity..."
    test_connectivity
    
    print_info "Testing authentication..."
    test_auth
    
    if [ -f "terraform/terraform.tfvars" ]; then
        print_info "Testing domain configuration..."
        test_domain
    fi
    
    print_success "All tests completed"
}

test_auth() {
    print_step "Testing authentication features"
    
    check_kubernetes
    
    local service_url="http://localhost:30080"
    
    print_info "Testing service availability..."
    if curl -s --max-time 10 "$service_url" >/dev/null; then
        print_success "Service is accessible"
    else
        print_error "Service is not accessible at $service_url"
        return 1
    fi
    
    print_info "Testing API configuration..."
    local config=$(curl -s "$service_url/api/config" 2>/dev/null || echo "{}")
    
    if [ "$config" != "{}" ]; then
        print_success "API is responding"
        echo "   OAuth Provider: $(echo "$config" | jq -r '.oauth.providers.oidc // "Not configured"')"
        echo "   Login Form: $(echo "$config" | jq -r '.features.enable_login_form // "Not configured"')"
    else
        print_warning "API configuration not accessible"
    fi
    
    print_info "Testing OAuth endpoint..."
    local oauth_response=$(curl -s -w "%{http_code}" -o /dev/null "$service_url/oauth/oidc/login" 2>/dev/null || echo "000")
    
    if [ "$oauth_response" = "302" ]; then
        print_success "OAuth redirect is working"
    else
        print_warning "OAuth endpoint returned: $oauth_response"
    fi
}

test_connectivity() {
    print_step "Testing network connectivity"
    
    check_kubernetes
    
    # Test pod status
    print_info "Checking pod status..."
    if kubectl get pods -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl get pods -n "$NAMESPACE"
    else
        print_warning "No pods found in namespace $NAMESPACE"
    fi
    
    # Test service status
    print_info "Checking service status..."
    if kubectl get services -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl get services -n "$NAMESPACE"
    else
        print_warning "No services found in namespace $NAMESPACE"
    fi
    
    # Test external connectivity
    print_info "Testing external connectivity..."
    local external_ip=$(kubectl get service -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$external_ip" ]; then
        print_success "External IP: $external_ip"
    else
        print_info "Using NodePort access"
    fi
}

test_dns() {
    print_step "Testing DNS configuration"
    
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found, skipping DNS tests"
        return 0
    fi
    
    local app_host=$(grep "^app_host" terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
    
    if [ -z "$app_host" ]; then
        print_warning "app_host not configured in terraform.tfvars"
        return 0
    fi
    
    print_info "Testing DNS resolution for $app_host..."
    
    if dig +short "$app_host" >/dev/null 2>&1; then
        local resolved_ip=$(dig +short "$app_host" | head -1)
        print_success "DNS resolves to: $resolved_ip"
    else
        print_warning "DNS resolution failed for $app_host"
    fi
}

test_domain() {
    print_step "Testing domain configuration"
    
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found"
        return 1
    fi
    
    print_info "Validating terraform.tfvars..."
    
    local app_host=$(grep "^app_host" terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
    local domain_name=$(grep "^domain_name" terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
    
    if [ -n "$app_host" ]; then
        print_success "app_host configured: $app_host"
    else
        print_warning "app_host not configured"
    fi
    
    if [ -n "$domain_name" ]; then
        print_success "domain_name configured: $domain_name"
    else
        print_info "domain_name not configured (optional)"
    fi
}

# Backend management functions
cmd_backend() {
    case "${2:-help}" in
        start)
            backend_start
            ;;
        stop)
            backend_stop
            ;;
        config)
            backend_config
            ;;
        test)
            backend_test
            ;;
        *)
            print_info "Backend commands:"
            echo "  start   - Start ADK backend services"
            echo "  stop    - Stop ADK backend services"
            echo "  config  - Configure backend for Ollama integration"
            echo "  test    - Test backend integration"
            ;;
    esac
}

cmd_stack() {
    case "${2:-help}" in
        start)
            stack_start
            ;;
        stop)
            stack_stop
            ;;
        *)
            print_info "Stack commands:"
            echo "  start   - Start full Ollama+ADK+OpenWebUI stack"
            echo "  stop    - Stop full stack"
            ;;
    esac
}

backend_start() {
    print_step "Starting ADK backend services"
    
    if [ ! -d "adk-backend" ]; then
        print_error "ADK backend directory not found"
        return 1
    fi
    
    cd adk-backend
    
    print_info "Checking if Docker Compose file exists..."
    if [ -f "docker-compose.yml" ]; then
        print_info "Starting services with Docker Compose..."
        docker-compose up -d
        
        print_info "Waiting for services to be ready..."
        sleep 10
        
        # Check service health
        if curl -s "http://localhost:8000" > /dev/null 2>&1; then
            print_success "ADK Backend is running at http://localhost:8000"
        else
            print_warning "ADK Backend may still be starting..."
        fi
    else
        print_info "Starting with Poetry..."
        if command -v poetry >/dev/null 2>&1; then
            poetry install
            print_info "Starting ADK API server..."
            poetry run adk api_server &
            print_success "ADK Backend started in background"
        else
            print_error "Poetry not found. Install Poetry or use Docker."
            return 1
        fi
    fi
    
    cd ..
}

backend_stop() {
    print_step "Stopping ADK backend services"
    
    if [ -d "adk-backend" ] && [ -f "adk-backend/docker-compose.yml" ]; then
        cd adk-backend
        docker-compose down
        cd ..
        print_success "Docker services stopped"
    fi
    
    # Kill any running Python processes for ADK
    pkill -f "adk api_server" 2>/dev/null || true
    print_success "Background processes stopped"
}

backend_config() {
    print_step "Configuring ADK backend for Ollama integration"
    
    if [ ! -f "adk-backend/configure_adk_ollama.sh" ]; then
        print_error "Ollama configuration script not found"
        return 1
    fi
    
    cd adk-backend
    
    print_info "Setting up Ollama configuration..."
    chmod +x configure_adk_ollama.sh
    source configure_adk_ollama.sh
    
    print_success "ADK configured for Ollama integration"
    print_info "Environment variables set:"
    echo "  LITELLM_PROXY_API_BASE: $LITELLM_PROXY_API_BASE"
    echo "  ROOT_AGENT_MODEL: $ROOT_AGENT_MODEL"
    echo ""
    print_info "To persist these settings, add them to your .env file"
    
    cd ..
}

backend_test() {
    print_step "Testing ADK backend integration"
    
    cd adk-backend
    
    print_info "Testing ADK backend connectivity..."
    if curl -s "http://localhost:8000" > /dev/null 2>&1; then
        print_success "ADK Backend is accessible"
    else
        print_error "ADK Backend is not running or not accessible"
        cd ..
        return 1
    fi
    
    if [ -f "test_ollama_cli_manual.sh" ]; then
        print_info "Running Ollama integration test..."
        chmod +x test_ollama_cli_manual.sh
        ./test_ollama_cli_manual.sh
    else
        print_warning "Manual test script not found"
    fi
    
    # Test basic API endpoint if available
    print_info "Testing API endpoints..."
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:8000/health" 2>/dev/null || echo "000")
        if [ "$response" = "200" ]; then
            print_success "Health endpoint responding correctly"
        else
            print_warning "Health endpoint not available (code: $response)"
        fi
    fi
    
    cd ..
}

stack_start() {
    print_step "Starting full Ollama+ADK+OpenWebUI stack"
    
    if [ ! -f "adk-backend/start-ollama-stack.sh" ]; then
        print_error "Stack start script not found"
        return 1
    fi
    
    cd adk-backend
    chmod +x start-ollama-stack.sh
    print_info "Starting complete stack..."
    ./start-ollama-stack.sh
    
    print_success "Stack startup initiated"
    print_info "Services will be available at:"
    echo "  - ADK Backend: http://localhost:8000"
    echo "  - Ollama Proxy: http://localhost:11434"
    echo "  - OpenWebUI: http://localhost:3000"
    
    cd ..
}

stack_stop() {
    print_step "Stopping full stack"
    
    cd adk-backend
    
    if [ -f "docker-compose.openwebui.yml" ]; then
        print_info "Stopping OpenWebUI stack..."
        docker-compose -f docker-compose.openwebui.yml down
    fi
    
    if [ -f "docker-compose.yml" ]; then
        print_info "Stopping ADK services..."
        docker-compose down
    fi
    
    # Stop any remaining processes
    print_info "Cleaning up background processes..."
    pkill -f "ollama" 2>/dev/null || true
    pkill -f "adk api_server" 2>/dev/null || true
    
    print_success "Full stack stopped"
    
    cd ..
}

# Status and info functions
cmd_status() {
    print_step "Deployment status"
    
    check_kubernetes
    
    # Show namespace status
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_warning "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
    
    # Show Helm release status
    if helm status "$RELEASE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_success "Helm release '$RELEASE_NAME' is deployed"
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
    else
        print_warning "Helm release '$RELEASE_NAME' not found"
    fi
    
    # Show resource status
    echo ""
    print_info "Resource status:"
    kubectl get all -n "$NAMESPACE" 2>/dev/null || print_warning "No resources found"
}

cmd_logs() {
    local service="${SUBCOMMAND:-all}"
    
    print_step "Showing logs for: $service"
    
    check_kubernetes
    
    if [ "$service" = "all" ]; then
        kubectl logs -n "$NAMESPACE" --all-containers=true -l app.kubernetes.io/instance="$RELEASE_NAME" --tail=50
    else
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/component="$service" --tail=50
    fi
}

cmd_info() {
    print_step "Connection information"
    show_connection_info
}

show_connection_info() {
    check_kubernetes
    
    # Get service information
    local external_ip=$(kubectl get service -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    local node_port=$(kubectl get service -n "$NAMESPACE" -o jsonpath='{.items[0].spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
    
    print_info "Access URLs:"
    
    if [ -n "$external_ip" ]; then
        echo "   🌐 External: http://$external_ip"
    fi
    
    echo "   🏠 Local: http://localhost:$node_port"
    
    # Check if custom domain is configured
    if [ -f "terraform/terraform.tfvars" ]; then
        local app_host=$(grep "^app_host" terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
        if [ -n "$app_host" ]; then
            echo "   🔗 Custom: https://$app_host"
        fi
    fi
    
    print_info "Management commands:"
    echo "   📊 Status: ./adk-mgmt.sh status"
    echo "   📝 Logs: ./adk-mgmt.sh logs"
    echo "   🧪 Test: ./adk-mgmt.sh test all"
}

cmd_resources() {
    print_step "Resource usage"
    
    check_kubernetes
    
    print_info "Pod resource usage:"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || print_warning "Metrics not available"
    
    print_info "Node resource usage:"
    kubectl top nodes 2>/dev/null || print_warning "Metrics not available"
}

# Management functions
cmd_restart() {
    local service="${SUBCOMMAND:-all}"
    
    print_step "Restarting: $service"
    
    check_kubernetes
    
    if [ "$service" = "all" ]; then
        kubectl rollout restart deployment -n "$NAMESPACE"
    else
        kubectl rollout restart deployment "$service" -n "$NAMESPACE"
    fi
    
    print_success "Restart initiated"
}

cmd_scale() {
    local replicas="${SUBCOMMAND:-1}"
    
    print_step "Scaling to $replicas replicas"
    
    check_kubernetes
    
    kubectl scale deployment --replicas="$replicas" -n "$NAMESPACE" --all
    
    print_success "Scaling initiated"
}

cmd_upgrade() {
    print_step "Upgrading deployment"
    
    # Re-run deployment with current configuration
    deploy_local
}

cmd_cleanup() {
    print_step "Cleaning up resources"
    
    check_kubernetes
    
    print_warning "This will delete all resources in namespace '$NAMESPACE'"
    if confirm_action "Continue with cleanup?"; then
        kubectl delete namespace "$NAMESPACE" --ignore-not-found
        print_success "Cleanup completed"
    fi
}

# Troubleshooting functions
cmd_fix() {
    case "$SUBCOMMAND" in
        oauth)
            fix_oauth
            ;;
        quota)
            fix_quota
            ;;
        *)
            print_error "Unknown fix command: $SUBCOMMAND"
            echo "Available: oauth, quota"
            exit 1
            ;;
    esac
}

fix_oauth() {
    print_step "OAuth troubleshooting"
    
    print_info "Common OAuth issues and solutions:"
    echo ""
    echo "1. Redirect URI mismatch:"
    echo "   Add these URIs to Google Cloud Console:"
    echo "   - http://localhost:30080/oauth/oidc/callback"
    echo "   - https://your-domain.com/oauth/oidc/callback"
    echo ""
    echo "2. Invalid client credentials:"
    echo "   Check OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET in .env"
    echo ""
    echo "3. Service not accessible:"
    echo "   Check if pods are running: kubectl get pods -n $NAMESPACE"
    
    if confirm_action "Test OAuth configuration now?"; then
        test_auth
    fi
}

fix_quota() {
    print_step "Quota troubleshooting"
    
    print_info "Checking current quota usage..."
    gcloud compute regions describe us-central1 --format="table(quotas.metric,quotas.usage,quotas.limit)" | grep CPUS || print_warning "Could not get quota information"
    
    print_info "Solutions for quota issues:"
    echo ""
    echo "1. Request quota increase:"
    echo "   - Go to Google Cloud Console > IAM & Admin > Quotas"
    echo "   - Search for 'CPUs' in us-central1"
    echo "   - Request increase to 64-96 CPUs"
    echo ""
    echo "2. Use quota-limited deployment:"
    echo "   ./adk-mgmt.sh deploy quota-limited"
    echo ""
    echo "3. Use different region:"
    echo "   Update terraform configuration to use different region"
}

cmd_debug() {
    print_step "Debug information"
    
    print_info "System information:"
    echo "   Kubectl version: $(kubectl version --client --short 2>/dev/null || echo 'Not available')"
    echo "   Helm version: $(helm version --short 2>/dev/null || echo 'Not available')"
    echo "   Docker version: $(docker --version 2>/dev/null || echo 'Not available')"
    
    print_info "Cluster information:"
    kubectl cluster-info 2>/dev/null || print_warning "Cannot connect to cluster"
    
    print_info "Namespace information:"
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        kubectl describe namespace "$NAMESPACE"
    else
        print_warning "Namespace '$NAMESPACE' does not exist"
    fi
    
    print_info "Recent events:"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10 2>/dev/null || print_warning "No events found"
}

# Main execution
main() {
    # Parse arguments
    parse_args "$@"
    
    # Check if command is provided
    if [ -z "$COMMAND" ]; then
        show_script_help
        exit 1
    fi
    
    # Execute command
    case "$COMMAND" in
        build)
            cmd_build
            ;;
        env)
            cmd_env
            ;;
        domain)
            cmd_domain
            ;;
        dns)
            cmd_dns
            ;;
        oauth)
            cmd_oauth
            ;;
        deploy)
            cmd_deploy
            ;;
        destroy)
            cmd_destroy
            ;;
        test)
            cmd_test
            ;;
        backend)
            cmd_backend
            ;;
        stack)
            cmd_stack
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs
            ;;
        info)
            cmd_info
            ;;
        resources)
            cmd_resources
            ;;
        restart)
            cmd_restart
            ;;
        scale)
            cmd_scale
            ;;
        upgrade)
            cmd_upgrade
            ;;
        cleanup)
            cmd_cleanup
            ;;
        fix)
            cmd_fix
            ;;
        debug)
            cmd_debug
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            echo ""
            show_script_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
