#!/bin/bash

# Quick DNS and Deployment Script
# This script sets up DNS and deploys the OpenWebUI ADK application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 OpenWebUI ADK - Quick DNS Setup and Deployment${NC}"
echo "=========================================================="

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

# Check required tools
for tool in gcloud terraform kubectl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        print_error "$tool is not installed. Please install it first."
        exit 1
    fi
done

print_step "1. Pre-deployment Checks"

# Check gcloud authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null 2>&1; then
    print_error "Please authenticate with gcloud: gcloud auth login"
    exit 1
fi

# Check project
current_project=$(gcloud config get-value project 2>/dev/null || true)
if [[ -z "$current_project" ]]; then
    print_error "No active GCP project. Please run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_success "GCP Project: $current_project"

# Check .env file
if [[ ! -f ".env" ]]; then
    print_error ".env file not found. Please create it based on .env.example"
    exit 1
fi

# Check terraform.tfvars
if [[ ! -f "terraform/terraform.tfvars" ]]; then
    print_error "terraform/terraform.tfvars not found. Please create it based on terraform.tfvars.example"
    exit 1
fi

print_success "Configuration files found"

# Ask user what they want to do
echo ""
print_step "2. Deployment Options"
echo ""
echo "Choose your deployment approach:"
echo ""
echo "1. 🌐 Setup DNS + Full Deployment (Recommended)"
echo "2. 🔧 Infrastructure Only (GKE + DNS zone)"
echo "3. 📦 Skip DNS, Deploy with LoadBalancer IP"
echo "4. 🧪 Test existing DNS configuration"
echo "5. ❌ Cancel"
echo ""

read -p "Select option (1-5): " choice

case $choice in
    1)
        echo ""
        print_step "🌐 DNS Setup + Full Deployment"
        
        # Run DNS setup
        if [[ -x "./setup-dns.sh" ]]; then
            print_step "Running DNS setup..."
            ./setup-dns.sh
        else
            print_error "setup-dns.sh not found or not executable"
            exit 1
        fi
        
        # Deploy everything
        print_step "Deploying infrastructure and application..."
        cd terraform
        
        echo ""
        print_warning "About to deploy:"
        echo "- GKE Autopilot cluster"
        echo "- DNS zone and records"
        echo "- NGINX Ingress Controller"
        echo "- cert-manager with Let's Encrypt"
        echo "- OpenWebUI ADK application"
        echo ""
        
        read -p "Continue with deployment? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            terraform apply -auto-approve
            deployment_success=true
        else
            print_warning "Deployment cancelled"
            exit 0
        fi
        ;;
        
    2)
        echo ""
        print_step "🔧 Infrastructure Only Deployment"
        
        # Run DNS setup
        if [[ -x "./setup-dns.sh" ]]; then
            print_step "Running DNS setup..."
            ./setup-dns.sh
        fi
        
        # Deploy infrastructure only
        print_step "Deploying infrastructure only..."
        cd terraform
        
        terraform apply -var="deploy_kubernetes_resources=false" -auto-approve
        deployment_success=true
        ;;
        
    3)
        echo ""
        print_step "📦 Deploy with LoadBalancer IP (No DNS)"
        
        # Update terraform.tfvars to skip DNS
        sed -i.bak 's/^create_dns_zone.*/create_dns_zone = false/' terraform/terraform.tfvars
        sed -i.bak 's/^domain_name.*/# domain_name = ""/' terraform/terraform.tfvars
        
        cd terraform
        terraform apply -auto-approve
        deployment_success=true
        ;;
        
    4)
        echo ""
        print_step "🧪 Testing DNS Configuration"
        
        if [[ -x "./test-dns.sh" ]]; then
            ./test-dns.sh
        else
            print_error "test-dns.sh not found or not executable"
            exit 1
        fi
        exit 0
        ;;
        
    5)
        print_warning "Cancelled"
        exit 0
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# Post-deployment steps
if [[ "$deployment_success" == "true" ]]; then
    echo ""
    print_step "3. Post-Deployment Information"
    echo "=============================================="
    
    # Show Terraform outputs
    terraform output
    
    echo ""
    print_step "4. Access Your Application"
    echo "=============================================="
    
    # Get application URL
    app_url=$(terraform output -raw app_url 2>/dev/null || echo "Not available")
    ingress_ip=$(terraform output -raw ingress_ip 2>/dev/null || echo "Not available")
    
    if [[ "$app_url" != "Not available" && "$app_url" != *"example.com"* ]]; then
        echo "🌐 Application URL: $app_url"
        echo ""
        echo "📋 DNS Setup Status:"
        
        # Check if DNS is configured
        domain_name=$(grep "^domain_name" terraform.tfvars | cut -d'"' -f2 2>/dev/null || true)
        if [[ -n "$domain_name" && "$domain_name" != "" ]]; then
            echo "   ✅ DNS zone configured for: $domain_name"
            echo "   ⚠️  Make sure to configure name servers at your domain registrar"
            echo "   📖 See DNS-SETUP-GUIDE.md for detailed instructions"
        else
            echo "   ⚠️  No custom domain configured"
        fi
    fi
    
    if [[ "$ingress_ip" != "Not available" ]]; then
        echo ""
        echo "🔗 Direct IP Access: http://$ingress_ip"
        echo "   (Use this while DNS propagates)"
    fi
    
    echo ""
    print_step "5. Monitoring and Management"
    echo "=============================================="
    echo ""
    echo "🔍 Check deployment status:"
    echo "   kubectl get pods -A"
    echo "   kubectl get svc -A"
    echo "   kubectl get ingress -A"
    echo ""
    echo "📊 View logs:"
    echo "   kubectl logs -f deployment/webui-adk-openwebui"
    echo "   kubectl logs -f deployment/webui-adk-adk-backend"
    echo ""
    echo "🧪 Test DNS (if configured):"
    echo "   ./test-dns.sh"
    echo ""
    echo "🔄 Update deployment:"
    echo "   terraform apply"
    echo ""
    
    print_step "6. Next Steps"
    echo "=============================================="
    
    if [[ "$choice" == "2" ]]; then
        echo "🚀 Complete the deployment:"
        echo "   terraform apply -var=\"deploy_kubernetes_resources=true\""
        echo ""
    fi
    
    echo "📋 Important notes:"
    echo "   - DNS propagation can take up to 48 hours"
    echo "   - HTTPS certificates are automatically provisioned"
    echo "   - Monitor cert-manager logs for certificate issues"
    echo "   - Use kubectl port-forward for immediate access during DNS propagation"
    echo ""
    
    print_success "Deployment complete!"
    
    # Open application in browser (optional)
    if [[ "$app_url" != "Not available" && "$app_url" != *"example.com"* ]]; then
        echo ""
        read -p "Open application in browser? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v open >/dev/null 2>&1; then
                open "$app_url"
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$app_url"
            else
                echo "Please open: $app_url"
            fi
        fi
    fi
fi
