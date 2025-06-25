#!/bin/bash

# Production Deployment Validation Script
# This script validates all requirements for successful production deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

print_header "🚀 Production Deployment Validation"

# Function to validate DNS setup
validate_dns() {
    print_step "Validating DNS Configuration"
    
    # Check if DNS zone exists
    local zone_name="agenticdatagovernance"
    if gcloud dns managed-zones describe "$zone_name" &>/dev/null; then
        print_success "DNS zone '$zone_name' exists"
        
        # Get the zone details
        local zone_dns_name=$(gcloud dns managed-zones describe "$zone_name" --format="value(dnsName)")
        print_info "Zone DNS name: $zone_dns_name"
        
        # Check name servers
        local name_servers=$(gcloud dns record-sets list --zone="$zone_name" --filter="type=NS" --format="value(rrdatas)" | tr ',' '\n' | head -4)
        print_info "Name servers:"
        echo "$name_servers" | sed 's/^/  - /'
        
    else
        print_error "DNS zone '$zone_name' not found"
        return 1
    fi
}

# Function to validate OAuth configuration
validate_oauth() {
    print_step "Validating OAuth Configuration"
    
    # Load environment variables
    if [ -f ".env" ]; then
        source .env
    else
        print_error ".env file not found"
        return 1
    fi
    
    if [ -n "$OAUTH_CLIENT_ID" ] && [ -n "$OAUTH_CLIENT_SECRET" ]; then
        print_success "OAuth credentials are configured"
        print_info "Client ID: $OAUTH_CLIENT_ID"
        
        # Check if production domain is configured
        if [ -f "terraform/terraform.tfvars.production" ]; then
            local app_host=$(grep '^app_host' terraform/terraform.tfvars.production | cut -d'"' -f2 2>/dev/null)
            if [ -n "$app_host" ]; then
                print_warning "Please verify OAuth redirect URIs include:"
                print_info "  ✓ https://$app_host/oauth/oidc/callback"
                print_info "  ✓ http://localhost:30080/oauth/oidc/callback"
                echo ""
                print_info "Update at: https://console.cloud.google.com/apis/credentials"
            fi
        fi
    else
        print_error "OAuth credentials not configured in .env"
        return 1
    fi
}

# Function to validate Terraform configuration
validate_terraform() {
    print_step "Validating Terraform Configuration"
    
    if [ -f "terraform/terraform.tfvars.production" ]; then
        print_success "Production tfvars file exists"
        
        # Check key configurations
        local app_host=$(grep '^app_host' terraform/terraform.tfvars.production | cut -d'"' -f2 2>/dev/null)
        local domain_name=$(grep '^domain_name' terraform/terraform.tfvars.production | cut -d'"' -f2 2>/dev/null)
        local dns_zone_name=$(grep '^dns_zone_name' terraform/terraform.tfvars.production | cut -d'"' -f2 2>/dev/null)
        local enable_https=$(grep '^enable_https' terraform/terraform.tfvars.production | awk '{print $3}' 2>/dev/null)
        local deploy_cert_manager=$(grep '^deploy_cert_manager' terraform/terraform.tfvars.production | awk '{print $3}' 2>/dev/null)
        
        print_info "App host: $app_host"
        print_info "Domain name: $domain_name"
        print_info "DNS zone name: $dns_zone_name"
        print_info "HTTPS enabled: $enable_https"
        print_info "Cert-manager enabled: $deploy_cert_manager"
        
        if [ "$app_host" = "agenticdatagovernance.com" ] && 
           [ "$domain_name" = "agenticdatagovernance.com" ] && 
           [ "$dns_zone_name" = "agenticdatagovernance" ] &&
           [ "$enable_https" = "true" ] &&
           [ "$deploy_cert_manager" = "true" ]; then
            print_success "Terraform configuration is correctly set for production"
        else
            print_warning "Some Terraform configurations may need review"
        fi
    else
        print_error "terraform/terraform.tfvars.production not found"
        return 1
    fi
}

# Function to validate Docker setup
validate_docker() {
    print_step "Validating Docker Configuration"
    
    # Check if Docker is running
    if docker info &>/dev/null; then
        print_success "Docker is running"
        
        # Check if buildx is available
        if docker buildx version &>/dev/null; then
            print_success "Docker buildx is available"
            
            # Check multiplatform builder
            if docker buildx inspect multiplatform &>/dev/null; then
                print_success "Multiplatform builder exists"
            else
                print_info "Multiplatform builder will be created during build"
            fi
        else
            print_error "Docker buildx not available"
            return 1
        fi
    else
        print_error "Docker is not running"
        return 1
    fi
}

# Function to validate GCP authentication
validate_gcp() {
    print_step "Validating GCP Authentication"
    
    # Check if gcloud is authenticated
    if gcloud auth application-default print-access-token &>/dev/null; then
        print_success "GCP authentication is configured"
        
        # Check current project
        local current_project=$(gcloud config get-value project 2>/dev/null || echo "")
        local expected_project="agenticds-hackathon-54443"
        
        if [ "$current_project" = "$expected_project" ]; then
            print_success "GCP project is correctly set: $current_project"
        else
            print_warning "GCP project is: $current_project (expected: $expected_project)"
            if confirm_action "Set GCP project to $expected_project?"; then
                gcloud config set project "$expected_project"
                print_success "GCP project updated"
            fi
        fi
        
        # Check required APIs
        local required_apis=("container.googleapis.com" "artifactregistry.googleapis.com" "dns.googleapis.com")
        for api in "${required_apis[@]}"; do
            if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
                print_success "API enabled: $api"
            else
                print_warning "API not enabled: $api"
            fi
        done
        
    else
        print_error "GCP authentication not configured"
        print_info "Run: gcloud auth application-default login"
        return 1
    fi
}

# Main validation
main() {
    echo ""
    
    local validation_passed=true
    
    # Run all validations
    validate_gcp || validation_passed=false
    echo ""
    
    validate_dns || validation_passed=false
    echo ""
    
    validate_oauth || validation_passed=false
    echo ""
    
    validate_terraform || validation_passed=false
    echo ""
    
    validate_docker || validation_passed=false
    echo ""
    
    # Final summary
    print_header "🎯 Validation Summary"
    
    if [ "$validation_passed" = "true" ]; then
        print_success "✅ All validations passed!"
        echo ""
        print_info "🚀 Ready for production deployment:"
        echo ""
        echo "  ./scripts/adk-mgmt.sh deploy production --dry-run    # Test deployment"
        echo "  ./scripts/adk-mgmt.sh deploy production              # Deploy to production"
        echo ""
        print_info "🌐 After deployment, your application will be available at:"
        echo "  https://agenticdatagovernance.com"
        echo ""
    else
        print_error "❌ Some validations failed"
        echo ""
        print_info "Please address the issues above before deploying to production."
        echo ""
        print_info "For help:"
        echo "  ./scripts/adk-mgmt.sh oauth setup    # Configure OAuth"
        echo "  ./scripts/adk-mgmt.sh env check      # Check environment"
        echo ""
        exit 1
    fi
}

# Run main function
main
