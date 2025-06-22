#!/bin/bash

# Quick Setup with nip.io (no domain purchase required)
# This script configures your deployment to use nip.io for immediate testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Quick Setup with nip.io (No Domain Purchase Required)${NC}"
echo "=============================================================="

# Function to print colored output
print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "terraform/main.tf" ]]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Get the LoadBalancer IP from Terraform output
print_step "1. Getting LoadBalancer IP..."
cd terraform

if ! terraform output ingress_ip >/dev/null 2>&1; then
    print_error "Cannot get ingress IP. Please run 'terraform apply' first to create the infrastructure."
    exit 1
fi

ingress_ip=$(terraform output -raw ingress_ip 2>/dev/null)
if [[ -z "$ingress_ip" || "$ingress_ip" == "null" ]]; then
    print_error "LoadBalancer IP not available. Please ensure infrastructure is deployed."
    exit 1
fi

print_success "LoadBalancer IP: $ingress_ip"

# Convert IP to nip.io format (replace dots with dashes)
nip_domain=$(echo "$ingress_ip" | tr '.' '-').nip.io
app_domain="app.$nip_domain"

print_step "2. Configuring nip.io domain..."
echo "   Domain: $nip_domain"
echo "   App URL: https://$app_domain"

# Backup existing terraform.tfvars
backup_file="terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
cp terraform.tfvars "$backup_file"
print_success "Backed up terraform.tfvars to $backup_file"

# Update terraform.tfvars with nip.io configuration
print_step "3. Updating terraform.tfvars..."

# Remove existing DNS configuration lines and add new ones
{
    grep -v "^domain_name\|^create_dns_zone\|^dns_zone_name\|^app_host" terraform.tfvars || true
    echo ""
    echo "# DNS Configuration (nip.io for testing)"
    echo "domain_name = \"$nip_domain\""
    echo "create_dns_zone = false  # Using external nip.io service"
    echo "dns_zone_name = \"nip-io-zone\""
    echo "app_host = \"$app_domain\""
} > terraform.tfvars.tmp

mv terraform.tfvars.tmp terraform.tfvars
print_success "Updated terraform.tfvars with nip.io configuration"

# Validate Terraform configuration
print_step "4. Validating Terraform configuration..."
if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration validation failed"
    exit 1
fi

# Show what will be deployed
print_step "5. Deployment Preview"
echo "=============================================="
terraform plan -var-file=terraform.tfvars

echo ""
print_step "6. Deploy Application"
echo "=============================================="
echo ""
print_warning "About to deploy with nip.io configuration:"
echo "   🌐 Domain: $nip_domain"
echo "   🔗 App URL: https://$app_domain"
echo "   📍 IP: $ingress_ip"
echo ""
echo "Benefits of nip.io:"
echo "   ✅ No domain purchase required"
echo "   ✅ Automatic DNS resolution"
echo "   ✅ HTTPS support with Let's Encrypt"
echo "   ✅ Works immediately"
echo ""

read -p "Continue with deployment? (y/N): " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_step "Deploying application..."
    terraform apply -auto-approve
    
    echo ""
    print_step "7. Deployment Complete!"
    echo "=============================================="
    
    # Get final outputs
    app_url=$(terraform output -raw app_url 2>/dev/null || echo "https://$app_domain")
    
    print_success "Application deployed successfully!"
    echo ""
    echo "🌐 Application URLs:"
    echo "   Primary: $app_url"
    echo "   Direct IP: http://$ingress_ip"
    echo ""
    echo "🔍 Check deployment status:"
    echo "   kubectl get pods -A"
    echo "   kubectl get ingress -A"
    echo ""
    echo "🧪 Test the application:"
    echo "   curl -k $app_url"
    echo ""
    echo "📋 Certificate status (may take a few minutes):"
    echo "   kubectl get certificate -A"
    echo "   kubectl describe certificate -A"
    echo ""
    
    # Test connectivity
    print_step "8. Testing Connectivity..."
    echo "Testing DNS resolution..."
    
    if dig +short "$app_domain" | grep -q "$ingress_ip"; then
        print_success "DNS resolution working: $app_domain -> $ingress_ip"
    else
        print_warning "DNS resolution may take a moment. Testing direct connection..."
    fi
    
    # Wait a moment and test HTTP
    echo "Testing HTTP connectivity..."
    sleep 5
    
    if curl -I --connect-timeout 10 "http://$ingress_ip" >/dev/null 2>&1; then
        print_success "LoadBalancer is responding"
    else
        print_warning "LoadBalancer may still be initializing"
    fi
    
    echo ""
    print_step "🎉 Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Your OpenWebUI ADK application is now accessible at:"
    echo "   🔗 $app_url"
    echo ""
    echo "Login with:"
    echo "   📧 Google SSO (recommended)"
    echo "   👤 Username/Password (admin account will be auto-created)"
    echo ""
    echo "Next steps:"
    echo "1. 🌐 Open $app_url in your browser"
    echo "2. 🔐 Login with your Google account (your-admin-email@example.com)"
    echo "3. 🧪 Test the AI agent functionality"
    echo ""
    echo "If you want a custom domain later:"
    echo "1. 🛒 Purchase a domain from Namecheap, Google Domains, etc."
    echo "2. 🔧 Run: ./setup-dns.sh"
    echo "3. 🚀 Deploy: terraform apply"
    
else
    print_warning "Deployment cancelled. Your configuration has been updated but not deployed."
    echo ""
    echo "To deploy later, run:"
    echo "   cd terraform && terraform apply"
fi

cd ..  # Return to project root
