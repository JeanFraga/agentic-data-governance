#!/bin/bash

# Google Cloud Domain Purchase and Setup Script
# This script helps you search for and purchase domains using Google Cloud Domains

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛒 Google Cloud Domain Purchase & Setup${NC}"
echo "=============================================="

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

# Check if gcloud is installed and authenticated
if ! command -v gcloud >/dev/null 2>&1; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 >/dev/null 2>&1; then
    print_error "Please authenticate with gcloud: gcloud auth login"
    exit 1
fi

# Get current project
current_project=$(gcloud config get-value project 2>/dev/null || true)
if [[ -z "$current_project" ]]; then
    print_error "No active GCP project. Please run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_success "Current GCP Project: $current_project"

# Enable Cloud Domains API
print_step "1. Enabling Google Cloud Domains API..."
gcloud services enable domains.googleapis.com --project="$current_project"
print_success "Cloud Domains API enabled"

# Domain search and purchase
print_step "2. Domain Search and Purchase"
echo ""
echo "Choose an option:"
echo "1. 🔍 Search for available domains"
echo "2. 📋 Check specific domain availability" 
echo "3. 💰 View domain pricing"
echo "4. 🛒 Purchase a domain"
echo "5. 📖 View purchased domains"
echo "6. ❌ Exit"
echo ""

read -p "Select option (1-6): " choice

case $choice in
    1)
        echo ""
        print_step "🔍 Domain Search"
        read -p "Enter keywords to search for domains (e.g., 'myapp ai data'): " keywords
        
        if [[ -n "$keywords" ]]; then
            echo ""
            print_step "Searching for domains containing: $keywords"
            
            # Search for .com domains
            echo "📋 Searching .com domains..."
            gcloud domains search --query="$keywords" --format="table(domainName,availability,priceInfo.yearly_price.units)" 2>/dev/null || {
                print_warning "Domain search failed. This feature might not be available in your region."
            }
        fi
        ;;
        
    2)
        echo ""
        print_step "📋 Domain Availability Check"
        read -p "Enter domain name to check (e.g., myapp.com): " domain_name
        
        if [[ -n "$domain_name" ]]; then
            echo ""
            print_step "Checking availability for: $domain_name"
            
            availability=$(gcloud domains search --query="$domain_name" --format="value(availability)" 2>/dev/null || echo "UNKNOWN")
            
            case $availability in
                "AVAILABLE")
                    print_success "$domain_name is available for purchase!"
                    
                    # Get pricing
                    pricing=$(gcloud domains search --query="$domain_name" --format="value(priceInfo.yearly_price.units)" 2>/dev/null || echo "Unknown")
                    if [[ "$pricing" != "Unknown" ]]; then
                        echo "💰 Annual price: \$${pricing} USD"
                    fi
                    
                    echo ""
                    read -p "Would you like to purchase this domain? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        print_step "Starting domain purchase process..."
                        gcloud domains register "$domain_name" --interactive
                    fi
                    ;;
                "UNAVAILABLE")
                    print_error "$domain_name is not available"
                    ;;
                *)
                    print_warning "Could not determine availability for $domain_name"
                    ;;
            esac
        fi
        ;;
        
    3)
        echo ""
        print_step "💰 Domain Pricing"
        echo "Common domain pricing (approximate):"
        echo "  .com: \$12-15/year"
        echo "  .org: \$12-15/year" 
        echo "  .net: \$12-15/year"
        echo "  .ai:  \$50-70/year"
        echo "  .io:  \$40-60/year"
        echo "  .app: \$20-25/year"
        echo ""
        echo "For exact pricing, search for a specific domain."
        ;;
        
    4)
        echo ""
        print_step "🛒 Domain Purchase"
        read -p "Enter domain name to purchase (e.g., myapp.com): " domain_name
        
        if [[ -n "$domain_name" ]]; then
            print_warning "This will start an interactive domain purchase process."
            print_warning "You'll need to provide contact information and payment details."
            echo ""
            read -p "Continue with purchase? (y/N): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_step "Starting domain registration..."
                gcloud domains register "$domain_name" --interactive
            else
                print_warning "Domain purchase cancelled"
            fi
        fi
        ;;
        
    5)
        echo ""
        print_step "📖 Your Purchased Domains"
        domains=$(gcloud domains list --format="table(domainName,createTime,state)" 2>/dev/null || true)
        
        if [[ -n "$domains" ]]; then
            echo "$domains"
        else
            print_warning "No domains found in this project"
        fi
        ;;
        
    6)
        print_warning "Exiting"
        exit 0
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_step "3. Next Steps After Domain Purchase"
echo "=============================================="
echo ""
echo "After purchasing a domain with Google Cloud Domains:"
echo ""
echo "✅ DNS is automatically managed by Google Cloud DNS"
echo "✅ No need to configure name servers manually"
echo "✅ DNSSEC is enabled by default"
echo ""
echo "🔧 To set up your application with the new domain:"
echo "1. Update terraform.tfvars with your new domain"
echo "2. Run: ./setup-dns.sh"
echo "3. Deploy: terraform apply"
echo ""
echo "📋 Alternative: Manual domain configuration"
echo "If you purchase from another registrar, you'll need to:"
echo "1. Configure Google Cloud DNS name servers"
echo "2. Wait for DNS propagation"
echo ""

print_step "4. Suggested Domain Names"
echo "=============================================="
echo ""
echo "Based on your project 'Agentic Data Governance', consider:"
echo ""
echo "🤖 AI/Agent focused:"
echo "  • agenticdata.com"
echo "  • dataagent.ai" 
echo "  • agentgov.io"
echo "  • smartgov.ai"
echo ""
echo "📊 Data focused:"
echo "  • datagovai.com"
echo "  • govdata.ai"
echo "  • datasmart.gov (if available)"
echo "  • aigovernance.org"
echo ""
echo "🏢 Professional:"
echo "  • agenticgov.com"
echo "  • datagovernance.ai"
echo "  • intelligov.com"
echo "  • govtech.ai"
echo ""

print_success "Domain purchase guide complete!"
