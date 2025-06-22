#!/bin/bash

# DNS Setup Script for OpenWebUI ADK Deployment
# This script sets up Google Cloud DNS for your domain and integrates with Terraform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

echo -e "${BLUE}🚀 DNS Setup for OpenWebUI ADK Deployment${NC}"
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
print_step "1. Checking required tools..."
for tool in gcloud terraform; do
    if command_exists "$tool"; then
        print_success "$tool is installed"
    else
        print_error "$tool is not installed. Please install it first."
        exit 1
    fi
done

# Check if we're in the right directory
if [[ ! -f "$TERRAFORM_DIR/main.tf" ]]; then
    print_error "Terraform configuration not found. Please run this script from the project root."
    exit 1
fi

# Get current project
current_project=$(gcloud config get-value project 2>/dev/null || true)
if [[ -z "$current_project" ]]; then
    print_error "No active GCP project found. Please run 'gcloud auth login' and 'gcloud config set project YOUR_PROJECT_ID'"
    exit 1
fi

print_success "Current GCP Project: $current_project"

# Check if terraform.tfvars exists
if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
    print_error "terraform.tfvars not found. Please create it based on terraform.tfvars.example"
    exit 1
fi

# Read domain configuration from user
print_step "2. Domain Configuration"
echo "This script will help you set up DNS for your domain."
echo "You can either:"
echo "  A) Create a new Google Cloud DNS zone for your domain"
echo "  B) Use an existing Google Cloud DNS zone"
echo "  C) Skip DNS setup (use LoadBalancer IP directly)"
echo ""

read -p "Enter your domain name (e.g., example.com) or press Enter to skip DNS setup: " domain_name

if [[ -z "$domain_name" ]]; then
    print_warning "Skipping DNS setup. You can access the app via LoadBalancer IP."
    
    # Update terraform.tfvars to disable DNS
    sed -i.bak 's/^# \?domain_name.*/# domain_name = ""/' "$TERRAFORM_DIR/terraform.tfvars"
    sed -i.bak 's/^# \?create_dns_zone.*/# create_dns_zone = false/' "$TERRAFORM_DIR/terraform.tfvars"
    
    print_success "DNS setup skipped. Run 'terraform apply' to deploy with LoadBalancer IP access."
    exit 0
fi

# Validate domain format
if [[ ! "$domain_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid domain format. Please enter a valid domain like 'example.com'"
    exit 1
fi

# Check if DNS zone already exists
print_step "3. Checking for existing DNS zones..."
existing_zones=$(gcloud dns managed-zones list --filter="dnsName:${domain_name}." --format="value(name)" 2>/dev/null || true)

if [[ -n "$existing_zones" ]]; then
    existing_zone_name=$(echo "$existing_zones" | head -n1)
    print_success "Found existing DNS zone: $existing_zone_name"
    
    echo ""
    echo "Options:"
    echo "  1) Use existing zone: $existing_zone_name"
    echo "  2) Create a new zone (will require different zone name)"
    echo "  3) Cancel"
    
    read -p "Choose option (1-3): " choice
    
    case $choice in
        1)
            use_existing=true
            dns_zone_name="$existing_zone_name"
            create_new_zone=false
            ;;
        2)
            use_existing=false
            create_new_zone=true
            read -p "Enter name for new DNS zone (e.g., my-app-dns-zone): " dns_zone_name
            ;;
        3)
            print_warning "DNS setup cancelled."
            exit 0
            ;;
        *)
            print_error "Invalid choice."
            exit 1
            ;;
    esac
else
    print_warning "No existing DNS zone found for $domain_name"
    use_existing=false
    create_new_zone=true
    
    # Generate default zone name
    default_zone_name="${domain_name//./-}-zone"
    read -p "Enter name for DNS zone [$default_zone_name]: " dns_zone_name
    dns_zone_name=${dns_zone_name:-$default_zone_name}
fi

# Set app_host
app_host="$domain_name"
read -p "Enter subdomain for the app (e.g., 'app' for app.$domain_name) or press Enter for root domain: " subdomain

if [[ -n "$subdomain" ]]; then
    app_host="$subdomain.$domain_name"
fi

# Enable DNS API
print_step "4. Enabling Google Cloud DNS API..."
gcloud services enable dns.googleapis.com --project="$current_project"
print_success "DNS API enabled"

# Create DNS zone if needed
if [[ "$create_new_zone" == "true" ]]; then
    print_step "5. Creating DNS zone: $dns_zone_name"
    
    if gcloud dns managed-zones describe "$dns_zone_name" --project="$current_project" >/dev/null 2>&1; then
        print_warning "DNS zone $dns_zone_name already exists"
    else
        gcloud dns managed-zones create "$dns_zone_name" \
            --description="DNS zone for $domain_name - managed by Terraform" \
            --dns-name="$domain_name." \
            --project="$current_project"
        print_success "DNS zone created: $dns_zone_name"
    fi
    
    # Get name servers
    name_servers=$(gcloud dns managed-zones describe "$dns_zone_name" --project="$current_project" --format="value(nameServers[].join(','))")
    
    print_step "📋 DNS Zone Configuration"
    echo "=============================================="
    echo "Zone Name: $dns_zone_name"
    echo "Domain: $domain_name"
    echo ""
    echo "Name Servers:"
    echo "$name_servers" | tr ',' '\n' | sed 's/^/  /'
    echo ""
    print_warning "IMPORTANT: Configure these name servers at your domain registrar!"
    echo "This is required for DNS to work properly."
fi

# Update terraform.tfvars
print_step "6. Updating Terraform configuration..."

# Backup current terraform.tfvars
cp "$TERRAFORM_DIR/terraform.tfvars" "$TERRAFORM_DIR/terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"

# Update the configuration
{
    grep -v "^domain_name\|^create_dns_zone\|^dns_zone_name\|^app_host" "$TERRAFORM_DIR/terraform.tfvars" || true
    echo ""
    echo "# DNS Configuration"
    echo "domain_name = \"$domain_name\""
    echo "create_dns_zone = $create_new_zone"
    echo "dns_zone_name = \"$dns_zone_name\""
    echo "app_host = \"$app_host\""
} > "$TERRAFORM_DIR/terraform.tfvars.tmp"

mv "$TERRAFORM_DIR/terraform.tfvars.tmp" "$TERRAFORM_DIR/terraform.tfvars"

print_success "Terraform configuration updated"

# Validate Terraform configuration
print_step "7. Validating Terraform configuration..."
cd "$TERRAFORM_DIR"

if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration validation failed"
    exit 1
fi

# Show what Terraform will do
print_step "8. Terraform Plan Preview"
echo "=============================================="
terraform plan -var-file=terraform.tfvars

echo ""
print_step "9. Next Steps"
echo "=============================================="

if [[ "$create_new_zone" == "true" ]]; then
    echo "🔄 Configure Domain Registrar:"
    echo "   Update your domain registrar with these name servers:"
    echo "   $name_servers" | tr ',' '\n' | sed 's/^/   /'
    echo ""
fi

echo "🚀 Deploy Infrastructure:"
echo "   cd $TERRAFORM_DIR"
echo "   terraform apply"
echo ""

echo "🔍 Monitor Deployment:"
echo "   terraform output ingress_ip"
echo "   terraform output app_url"
echo ""

echo "🧪 Test Domain Resolution:"
echo "   dig $app_host"
echo "   nslookup $app_host"
echo ""

print_success "DNS setup complete! Your domain will be: https://$app_host"

# Optional: Create import script for existing zones
if [[ "$use_existing" == "true" ]]; then
    cat > "$SCRIPT_DIR/import-dns-zone.sh" << EOF
#!/bin/bash
# Generated script to import existing DNS zone into Terraform

echo "Importing existing DNS zone into Terraform state..."
cd "$TERRAFORM_DIR"

# Import the existing DNS zone
terraform import 'data.google_dns_managed_zone.existing_zone[0]' projects/$current_project/managedZones/$dns_zone_name

echo "Import complete. You can now run 'terraform plan' to see what changes will be made."
EOF
    
    chmod +x "$SCRIPT_DIR/import-dns-zone.sh"
    print_success "Created import-dns-zone.sh for importing existing zone"
fi

echo ""
print_warning "Remember to configure your domain registrar with the name servers shown above!"
        
        read -p "Enter your domain name (e.g., 'example.com'): " domain_name
        read -p "Enter DNS zone name (e.g., 'webui-zone'): " zone_name
        read -p "Enter description for the zone: " zone_description
        
        # Validate domain format
        if [[ ! "$domain_name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            echo -e "${RED}❌ Invalid domain format${NC}"
            exit 1
        fi
        
        echo ""
        echo -e "${BLUE}🔧 Creating DNS zone...${NC}"
        
        # Create the DNS zone
        if gcloud dns managed-zones create "$zone_name" \
            --description="$zone_description" \
            --dns-name="$domain_name." \
            --visibility=public; then
            
            echo -e "${GREEN}✅ DNS zone created successfully!${NC}"
            echo ""
            
            # Get name servers
            echo -e "${GREEN}📋 Name Servers for $domain_name:${NC}"
            name_servers=$(gcloud dns managed-zones describe "$zone_name" --format="value(nameServers[].join(','))")
            echo "$name_servers" | tr ',' '\n' | sed 's/^/  /'
            
            echo ""
            echo -e "${YELLOW}📝 Configure these name servers at your domain registrar:${NC}"
            echo "$name_servers" | tr ',' '\n' | sed 's/^/  /'
            
            # Update .env file with domain information
            if [ -f ".env" ]; then
                echo ""
                echo -e "${BLUE}🔧 Updating .env file...${NC}"
                
                if grep -q "^DOMAIN_NAME=" .env; then
                    sed -i.bak "s/^DOMAIN_NAME=.*/DOMAIN_NAME=$domain_name/" .env
                else
                    echo "DOMAIN_NAME=$domain_name" >> .env
                fi
                
                if grep -q "^DNS_ZONE_NAME=" .env; then
                    sed -i.bak "s/^DNS_ZONE_NAME=.*/DNS_ZONE_NAME=$zone_name/" .env
                else
                    echo "DNS_ZONE_NAME=$zone_name" >> .env
                fi
                
                rm -f .env.bak
                echo -e "${GREEN}✅ Updated .env file${NC}"
            fi
            
            # Update terraform.tfvars
            if [ -f "terraform/terraform.tfvars" ]; then
                echo -e "${BLUE}🔧 Updating terraform.tfvars...${NC}"
                
                # Update or add domain configuration
                if grep -q "^domain_name" terraform/terraform.tfvars; then
                    sed -i.bak "s/^domain_name.*$/domain_name         = \"$domain_name\"/" terraform/terraform.tfvars
                else
                    echo "domain_name         = \"$domain_name\"" >> terraform/terraform.tfvars
                fi
                
                if grep -q "^dns_zone_name" terraform/terraform.tfvars; then
                    sed -i.bak "s/^dns_zone_name.*$/dns_zone_name       = \"$zone_name\"/" terraform/terraform.tfvars
                else
                    echo "dns_zone_name       = \"$zone_name\"" >> terraform/terraform.tfvars
                fi
                
                if grep -q "^create_dns_zone" terraform/terraform.tfvars; then
                    sed -i.bak "s/^create_dns_zone.*$/create_dns_zone     = false  # Zone already exists/" terraform/terraform.tfvars
                else
                    echo "create_dns_zone     = false  # Zone already exists" >> terraform/terraform.tfvars
                fi
                
                rm -f terraform/terraform.tfvars.bak
                echo -e "${GREEN}✅ Updated terraform.tfvars${NC}"
            fi
            
        else
            echo -e "${RED}❌ Failed to create DNS zone${NC}"
            exit 1
        fi
        ;;
        
    2)
        echo -e "${GREEN}🔄 Import existing DNS zone to Terraform${NC}"
        echo ""
        
        # List existing zones
        echo -e "${BLUE}📋 Existing DNS zones:${NC}"
        gcloud dns managed-zones list --format="table(name,dnsName,description)"
        echo ""
        
        read -p "Enter the name of the DNS zone to import: " zone_name
        
        # Get zone details
        if zone_info=$(gcloud dns managed-zones describe "$zone_name" 2>/dev/null); then
            domain_name=$(echo "$zone_info" | grep "dnsName:" | cut -d' ' -f2 | sed 's/.$//')
            
            echo ""
            echo -e "${GREEN}📋 Zone Details:${NC}"
            echo "  Zone Name: $zone_name"
            echo "  Domain: $domain_name"
            
            # Add import command to a script
            cat > import-dns-zone.sh << EOF
#!/bin/bash
# Import existing DNS zone to Terraform

echo "Importing DNS zone $zone_name to Terraform..."

# Import the zone
terraform import google_dns_managed_zone.domain_zone[0] $zone_name

echo "DNS zone imported successfully!"
echo "Run 'terraform plan' to verify the import."
EOF
            
            chmod +x import-dns-zone.sh
            echo ""
            echo -e "${GREEN}✅ Created import-dns-zone.sh script${NC}"
            echo "Run ./import-dns-zone.sh to import the zone to Terraform"
            
        else
            echo -e "${RED}❌ DNS zone '$zone_name' not found${NC}"
            exit 1
        fi
        ;;
        
    3)
        echo -e "${GREEN}📋 Listing existing DNS zones${NC}"
        echo ""
        
        if zones=$(gcloud dns managed-zones list --format="table(name,dnsName,description,visibility)" 2>/dev/null); then
            echo "$zones"
            
            echo ""
            echo -e "${BLUE}🔍 Zone Details:${NC}"
            zone_count=$(gcloud dns managed-zones list --format="value(name)" | wc -l)
            echo "Total zones: $zone_count"
            
            if [ "$zone_count" -gt 0 ]; then
                echo ""
                echo -e "${YELLOW}💡 To use an existing zone with Terraform:${NC}"
                echo "1. Run this script again and select option 2 (Import)"
                echo "2. Or manually configure terraform.tfvars with the zone details"
            fi
        else
            echo "No DNS zones found in project $PROJECT_ID"
        fi
        ;;
        
    4)
        echo -e "${GREEN}🧪 Testing DNS configuration${NC}"
        echo ""
        
        if [ -f ".env" ] && grep -q "^DOMAIN_NAME=" .env; then
            domain_name=$(grep "^DOMAIN_NAME=" .env | cut -d'=' -f2)
            echo "Testing domain from .env: $domain_name"
        else
            read -p "Enter domain to test: " domain_name
        fi
        
        echo ""
        echo -e "${BLUE}🔍 DNS Resolution Test:${NC}"
        
        # Test with different DNS servers
        echo "Testing with Google DNS (8.8.8.8):"
        dig @8.8.8.8 "$domain_name" A +short || echo "  No A record found"
        
        echo ""
        echo "Testing with Cloudflare DNS (1.1.1.1):"
        dig @1.1.1.1 "$domain_name" A +short || echo "  No A record found"
        
        echo ""
        echo "Testing NS records:"
        dig "$domain_name" NS +short || echo "  No NS records found"
        
        echo ""
        echo -e "${BLUE}🌐 Web connectivity test:${NC}"
        if curl -s -I "http://$domain_name" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HTTP accessible${NC}"
        else
            echo -e "${YELLOW}⚠️  HTTP not accessible (may be normal)${NC}"
        fi
        
        if curl -s -I "https://$domain_name" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HTTPS accessible${NC}"
        else
            echo -e "${YELLOW}⚠️  HTTPS not accessible (may be normal)${NC}"
        fi
        ;;
        
    5)
        echo -e "${GREEN}🏗️  Setting up complete Terraform DNS management${NC}"
        echo ""
        
        read -p "Enter your domain name (e.g., 'example.com'): " domain_name
        read -p "Enter app subdomain (e.g., 'webui.example.com'): " app_host
        read -p "Enter email for TLS certificates: " tls_email
        
        # Update terraform.tfvars for complete automation
        if [ -f "terraform/terraform.tfvars" ]; then
            cp terraform/terraform.tfvars terraform/terraform.tfvars.backup
            
            # Update all domain-related settings
            sed -i.bak "s/^app_host.*$/app_host            = \"$app_host\"/" terraform/terraform.tfvars
            sed -i.bak "s/^domain_name.*$/domain_name         = \"$domain_name\"/" terraform/terraform.tfvars
            sed -i.bak "s/^create_dns_zone.*$/create_dns_zone     = true/" terraform/terraform.tfvars
            sed -i.bak "s/^enable_https.*$/enable_https        = true/" terraform/terraform.tfvars
            sed -i.bak "s/^tls_email.*$/tls_email           = \"$tls_email\"/" terraform/terraform.tfvars
            
            rm -f terraform/terraform.tfvars.bak
            
            echo -e "${GREEN}✅ Terraform configuration updated${NC}"
            echo ""
            echo -e "${YELLOW}📋 Next steps:${NC}"
            echo "1. cd terraform"
            echo "2. terraform plan"
            echo "3. terraform apply"
            echo "4. Configure name servers at your domain registrar"
            echo "5. Access your app at: https://$app_host"
            
        else
            echo -e "${RED}❌ terraform.tfvars not found${NC}"
            echo "Please run ./setup-domain.sh first"
        fi
        ;;
        
    *)
        echo -e "${RED}❌ Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}📚 Additional Resources:${NC}"
echo "• DNS Management Guide: CUSTOM-DOMAIN-SETUP.md"
echo "• Validate setup: ./test-domain-setup.sh"
echo "• GCP Console: https://console.cloud.google.com/net-services/dns/zones?project=$PROJECT_ID"
echo ""
echo -e "${GREEN}🎉 DNS configuration complete!${NC}"
