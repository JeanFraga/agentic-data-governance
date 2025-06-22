#!/bin/bash

# DNS Validation and Testing Script
# This script validates DNS configuration and tests domain resolution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 DNS Validation and Testing${NC}"
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

# Check required tools
for tool in dig nslookup gcloud; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        print_warning "$tool is not installed. Some tests may be skipped."
    fi
done

# Get current project
current_project=$(gcloud config get-value project 2>/dev/null || true)
if [[ -z "$current_project" ]]; then
    print_error "No active GCP project found."
    exit 1
fi

print_success "Current GCP Project: $current_project"

# Function to test domain resolution
test_domain_resolution() {
    local domain="$1"
    local expected_ip="$2"
    
    print_step "Testing domain resolution for: $domain"
    
    if command -v dig >/dev/null 2>&1; then
        echo "Using dig:"
        dig_result=$(dig +short "$domain" A 2>/dev/null || true)
        if [[ -n "$dig_result" ]]; then
            echo "  $domain -> $dig_result"
            if [[ "$dig_result" == "$expected_ip" ]]; then
                print_success "DNS resolution matches expected IP"
            else
                print_warning "DNS resolution ($dig_result) doesn't match expected IP ($expected_ip)"
            fi
        else
            print_warning "No A record found for $domain"
        fi
    fi
    
    if command -v nslookup >/dev/null 2>&1; then
        echo ""
        echo "Using nslookup:"
        nslookup_result=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | tail -n1 | awk '{print $2}' || true)
        if [[ -n "$nslookup_result" ]]; then
            echo "  $domain -> $nslookup_result"
        else
            print_warning "nslookup didn't return results for $domain"
        fi
    fi
    
    echo ""
}

# Read domain from user or terraform.tfvars
domain_name=""
app_host=""

if [[ -f "terraform/terraform.tfvars" ]]; then
    domain_name=$(grep "^domain_name" terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || true)
    app_host=$(grep "^app_host" terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || true)
fi

if [[ -z "$domain_name" ]]; then
    read -p "Enter your domain name to test (e.g., example.com): " domain_name
fi

if [[ -z "$app_host" ]]; then
    app_host="$domain_name"
fi

# List DNS zones
print_step "1. Listing DNS zones in project: $current_project"
gcloud dns managed-zones list --project="$current_project" --format="table(name,dnsName,description)"
echo ""

# Check if zone exists for domain
if [[ -n "$domain_name" ]]; then
    existing_zones=$(gcloud dns managed-zones list --filter="dnsName:${domain_name}." --format="value(name)" 2>/dev/null || true)
    
    if [[ -n "$existing_zones" ]]; then
        zone_name=$(echo "$existing_zones" | head -n1)
        print_success "Found DNS zone: $zone_name for domain: $domain_name"
        
        print_step "2. DNS Zone Details"
        gcloud dns managed-zones describe "$zone_name" --project="$current_project"
        echo ""
        
        print_step "3. DNS Records in Zone"
        gcloud dns record-sets list --zone="$zone_name" --project="$current_project"
        echo ""
        
        # Get name servers
        name_servers=$(gcloud dns managed-zones describe "$zone_name" --project="$current_project" --format="value(nameServers[].join(','))")
        print_step "4. Name Servers"
        echo "Configure these at your domain registrar:"
        echo "$name_servers" | tr ',' '\n' | sed 's/^/  /'
        echo ""
        
    else
        print_warning "No DNS zone found for domain: $domain_name"
    fi
fi

# Get ingress IP if available
ingress_ip=""
if kubectl get svc ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
    ingress_ip=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [[ -n "$ingress_ip" ]]; then
        print_success "Ingress LoadBalancer IP: $ingress_ip"
    else
        print_warning "Ingress LoadBalancer IP not available yet"
    fi
fi

# Test domain resolution
if [[ -n "$domain_name" ]]; then
    print_step "5. Domain Resolution Tests"
    
    # Test root domain
    test_domain_resolution "$domain_name" "$ingress_ip"
    
    # Test app host if different
    if [[ "$app_host" != "$domain_name" ]]; then
        test_domain_resolution "$app_host" "$ingress_ip"
    fi
    
    # Test www subdomain
    test_domain_resolution "www.$domain_name" "$ingress_ip"
fi

# Check HTTPS certificate (if domain resolves)
if [[ -n "$app_host" ]] && command -v curl >/dev/null 2>&1; then
    print_step "6. HTTPS Certificate Test"
    
    if curl -Is "https://$app_host" >/dev/null 2>&1; then
        print_success "HTTPS is working for $app_host"
        
        # Get certificate details
        cert_info=$(curl -vI "https://$app_host" 2>&1 | grep -E "(subject|issuer|expire)" || true)
        if [[ -n "$cert_info" ]]; then
            echo "Certificate details:"
            echo "$cert_info" | sed 's/^/  /'
        fi
    else
        print_warning "HTTPS not working for $app_host (certificate might still be provisioning)"
    fi
    echo ""
fi

# Final recommendations
print_step "7. Recommendations"
echo "=============================================="

if [[ -n "$existing_zones" ]]; then
    echo "✅ DNS zone is configured"
    echo "✅ Name servers are available"
    
    if [[ -n "$ingress_ip" ]]; then
        echo "✅ Ingress LoadBalancer is ready"
        echo ""
        echo "📋 Next steps:"
        echo "1. Ensure name servers are configured at your domain registrar"
        echo "2. Wait for DNS propagation (can take up to 48 hours)"
        echo "3. Test your application at: https://$app_host"
    else
        echo "⏳ Waiting for ingress LoadBalancer IP"
        echo ""
        echo "📋 Next steps:"
        echo "1. Wait for ingress deployment to complete"
        echo "2. Run: kubectl get svc ingress-nginx-controller -n ingress-nginx"
    fi
else
    echo "⚠️  No DNS zone found"
    echo ""
    echo "📋 Next steps:"
    echo "1. Run: ./setup-dns.sh to create DNS zone"
    echo "2. Configure name servers at your domain registrar"
    echo "3. Deploy application with Terraform"
fi

echo ""
print_success "DNS validation complete!"
