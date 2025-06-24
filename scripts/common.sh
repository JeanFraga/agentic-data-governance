#!/bin/bash

# Script Helper Functions
# Source this file in other scripts for consistent help and formatting

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "$(printf '=%.0s' $(seq 1 ${#1}))"
}

print_step() {
    echo -e "${GREEN}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Help function template
show_help() {
    local script_name=$(basename "$0")
    local description="$1"
    local usage="$2"
    local examples="$3"
    
    print_header "$script_name - $description"
    echo ""
    echo "USAGE:"
    echo "  $usage"
    echo ""
    if [ -n "$examples" ]; then
        echo "EXAMPLES:"
        echo "$examples"
        echo ""
    fi
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "DOCUMENTATION:"
    echo "  📖 Full guide: ./scripts/README.md"
    echo "  🚀 Quick ref:  ./scripts/QUICK-REFERENCE.md"
    echo ""
}

# Check prerequisites function
check_prerequisites() {
    local tools=("$@")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Please install the missing tools and try again."
        echo "See scripts/README.md for installation instructions."
        exit 1
    fi
}

# Check if .env file exists
check_env_file() {
    local env_file="${1:-.env}"
    
    if [ ! -f "$env_file" ]; then
        print_error ".env file not found"
        echo ""
        echo "Please create and configure your .env file:"
        echo "  cp .env.example .env"
        echo "  # Edit .env with your actual values"
        echo ""
        echo "Then run: ./scripts/check-env-simple.sh"
        exit 1
    fi
}

# Load environment variables
load_env() {
    local env_file="${1:-.env}"
    
    check_env_file "$env_file"
    
    print_step "Loading environment variables from $env_file..."
    set -a  # Automatically export all variables
    source "$env_file"
    set +a
}

# Check if running from project root
check_project_root() {
    if [ ! -f "terraform/main.tf" ] || [ ! -d "scripts" ]; then
        print_error "Please run this script from the project root directory"
        echo ""
        echo "Current directory: $(pwd)"
        echo "Expected files: terraform/main.tf, scripts/"
        exit 1
    fi
}

# Confirm action
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$message [Y/n]: " yn
            yn=${yn:-y}
        else
            read -p "$message [y/N]: " yn
            yn=${yn:-n}
        fi
        
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Wait for user input
wait_for_user() {
    local message="${1:-Press any key to continue...}"
    read -p "$message"
}

# Check if Kubernetes is accessible
check_kubernetes() {
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        echo ""
        echo "Please ensure:"
        echo "  - kubectl is installed and configured"
        echo "  - You have access to the cluster"
        echo "  - Your kubeconfig is correct"
        exit 1
    fi
}

# Check if in correct namespace
check_namespace() {
    local namespace="$1"
    
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        print_warning "Namespace '$namespace' does not exist"
        if confirm_action "Create namespace '$namespace'?"; then
            kubectl create namespace "$namespace"
            print_success "Created namespace '$namespace'"
        else
            exit 1
        fi
    fi
}

# Show script completion
show_completion() {
    local script_name=$(basename "$0")
    print_success "$script_name completed successfully!"
    echo ""
    echo "Next steps:"
    echo "$1"
    echo ""
    echo "Need help? Check: ./scripts/README.md"
}
