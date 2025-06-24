#!/bin/bash

# Script Migration Guide and Wrapper
# This script helps transition from individual scripts to the unified adk-mgmt.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "$(printf '=%.0s' $(seq 1 ${#1}))"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Script mapping function
get_new_command() {
    local script="$1"
    case "$script" in
        "check-env-simple.sh") echo "adk-mgmt.sh env check" ;;
        "check-env.sh") echo "adk-mgmt.sh env check" ;;
        "setup-domain.sh") echo "adk-mgmt.sh domain setup" ;;
        "setup-dns.sh") echo "adk-mgmt.sh dns setup" ;;
        "setup-oauth.sh") echo "adk-mgmt.sh oauth setup" ;;
        "deploy-secure.sh") echo "adk-mgmt.sh deploy local" ;;
        "deploy-gke-production.sh") echo "adk-mgmt.sh deploy production" ;;
        "deploy-quota-limited.sh") echo "adk-mgmt.sh deploy quota-limited" ;;
        "quick-deploy.sh") echo "adk-mgmt.sh deploy quick" ;;
        "test-dns.sh") echo "adk-mgmt.sh test dns" ;;
        "test-domain-setup.sh") echo "adk-mgmt.sh test domain" ;;
        "test-dual-auth.sh") echo "adk-mgmt.sh test auth" ;;
        "test-loadbalancer.sh") echo "adk-mgmt.sh test connectivity" ;;
        "verify-auth-complete.sh") echo "adk-mgmt.sh test auth" ;;
        "validate-terraform.sh") echo "adk-mgmt.sh test domain" ;;
        "configure_adk_ollama.sh") echo "adk-mgmt.sh backend config" ;;
        "start-ollama-stack.sh") echo "adk-mgmt.sh stack start" ;;
        "test_ollama_cli_manual.sh") echo "adk-mgmt.sh backend test" ;;
        *) echo "" ;;
    esac
}

show_all_mappings() {
    echo "check-env-simple.sh | adk-mgmt.sh env check"
    echo "check-env.sh | adk-mgmt.sh env check"
    echo "setup-domain.sh | adk-mgmt.sh domain setup"
    echo "setup-dns.sh | adk-mgmt.sh dns setup"
    echo "setup-oauth.sh | adk-mgmt.sh oauth setup"
    echo "deploy-secure.sh | adk-mgmt.sh deploy local"
    echo "deploy-gke-production.sh | adk-mgmt.sh deploy production"
    echo "deploy-quota-limited.sh | adk-mgmt.sh deploy quota-limited"
    echo "quick-deploy.sh | adk-mgmt.sh deploy quick"
    echo "test-dns.sh | adk-mgmt.sh test dns"
    echo "test-domain-setup.sh | adk-mgmt.sh test domain"
    echo "test-dual-auth.sh | adk-mgmt.sh test auth"
    echo "test-loadbalancer.sh | adk-mgmt.sh test connectivity"
    echo "verify-auth-complete.sh | adk-mgmt.sh test auth"
    echo "validate-terraform.sh | adk-mgmt.sh test domain"
    echo "configure_adk_ollama.sh | adk-mgmt.sh backend config"
    echo "start-ollama-stack.sh | adk-mgmt.sh stack start"
    echo "test_ollama_cli_manual.sh | adk-mgmt.sh backend test"
}

show_migration_help() {
    print_header "Script Migration Guide"
    echo ""
    print_info "All individual scripts have been consolidated into a unified management script!"
    echo ""
    print_success "Use the new unified commands:"
    echo ""
    echo "   🔧 Environment:"
    echo "     ./scripts/adk-mgmt.sh env check        # Check environment"
    echo "     ./scripts/adk-mgmt.sh domain setup     # Configure domain"
    echo "     ./scripts/adk-mgmt.sh dns setup        # Set up DNS"
    echo ""
    echo "   🚀 Deployment:"
    echo "     ./scripts/adk-mgmt.sh deploy local     # Local deployment"
    echo "     ./scripts/adk-mgmt.sh deploy production # Production deployment"
    echo "     ./scripts/adk-mgmt.sh deploy quick     # Quick deployment"
    echo ""
    echo "   🔧 Backend Development:"
    echo "     ./scripts/adk-mgmt.sh backend config   # Configure Ollama"
    echo "     ./scripts/adk-mgmt.sh backend start    # Start backend"
    echo "     ./scripts/adk-mgmt.sh stack start      # Start full stack"
    echo ""
    echo "   🧪 Testing:"
    echo "     ./scripts/adk-mgmt.sh test all         # Run all tests"
    echo "     ./scripts/adk-mgmt.sh test auth        # Test authentication"
    echo "     ./scripts/adk-mgmt.sh test dns         # Test DNS"
    echo ""
    echo "   📊 Management:"
    echo "     ./scripts/adk-mgmt.sh status           # Show status"
    echo "     ./scripts/adk-mgmt.sh logs             # Show logs"
    echo ""
    echo "   For full help: ./scripts/adk-mgmt.sh --help"
    echo ""
    print_info "All old scripts are backed up in scripts/legacy/"
    
    echo ""
    print_header "Migration Mapping"
    echo ""
    printf "%-30s | %s\n" "Old Script" "New Command"
    printf "%-30s-+--%s\n" "$(printf '%*s' 30 '' | tr ' ' '-')" "$(printf '%*s' 40 '' | tr ' ' '-')"
    
    show_all_mappings | while IFS='|' read -r old_script new_command; do
        printf "%-30s | %s\n" "$(echo "$old_script" | xargs)" "$(echo "$new_command" | xargs)"
    done
}

# Main logic
if [ $# -gt 0 ]; then
    script_name="$1"
    
    # Remove .sh extension if present, then add it back
    script_name="${script_name%.sh}"
    script_name="${script_name}.sh"
    
    if [[ -n "$(get_new_command "$script_name")" ]]; then
        new_command="$(get_new_command "$script_name")"
        
        print_warning "The script '$script_name' has been consolidated into the unified management script"
        echo ""
        print_info "Old command: ./scripts/$script_name"
        print_success "New command: ./scripts/$new_command"
        echo ""
        
        read -p "Run the new command now? [Y/n]: " yn
        yn=${yn:-y}
        case $yn in
            [Yy]* )
                print_info "Running: ./scripts/$new_command"
                exec ./scripts/$new_command
                ;;
            * )
                print_info "You can run it manually: ./scripts/$new_command"
                ;;
        esac
    else
        print_warning "Script '$script_name' not found in migration mapping"
        echo ""
        show_migration_help
    fi
else
    show_migration_help
fi
