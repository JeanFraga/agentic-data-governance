#!/bin/bash

# Domain Setup Helper Script
# This script helps configure custom domain settings for Terraform deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Custom Domain Setup Helper${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "terraform/terraform.tfvars.example" ]; then
    echo -e "${RED}❌ Please run this script from the project root directory${NC}"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${YELLOW}📋 Creating terraform.tfvars from example...${NC}"
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo -e "${GREEN}✅ Created terraform/terraform.tfvars${NC}"
fi

echo -e "${GREEN}🎯 Domain Configuration Setup${NC}"
echo ""

# Get current values from terraform.tfvars if they exist
current_app_host=$(grep "^app_host" terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "")
current_domain=$(grep "^domain_name" terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "")
current_dns_zone=$(grep "^create_dns_zone" terraform/terraform.tfvars 2>/dev/null | cut -d'=' -f2 | xargs || echo "false")

echo "Current configuration:"
echo "  App Host: ${current_app_host:-'Not set'}"
echo "  Domain: ${current_domain:-'Not set'}"
echo "  DNS Management: ${current_dns_zone:-'false'}"
echo ""

# Domain configuration options
echo -e "${YELLOW}📋 Choose your domain setup option:${NC}"
echo ""
echo "1. 🚀 Full automatic setup (Google Cloud DNS + domain)"
echo "2. 🔧 Use existing DNS provider (external DNS management)"
echo "3. 💻 Local/development setup (use IP address)"
echo "4. ❌ Skip domain configuration"
echo ""

read -p "Select option (1-4): " -n 1 -r
echo
echo ""

case $REPLY in
    1)
        echo -e "${GREEN}🚀 Setting up full automatic domain management${NC}"
        echo ""
        
        read -p "Enter your root domain (e.g., 'example.com'): " domain_name
        read -p "Enter your app subdomain (e.g., 'webui.example.com'): " app_host
        read -p "Enter email for TLS certificates (e.g., 'admin@example.com'): " tls_email
        
        # Update terraform.tfvars
        sed -i.bak "s/^app_host.*$/app_host            = \"$app_host\"/" terraform/terraform.tfvars
        sed -i.bak "s/^domain_name.*$/domain_name         = \"$domain_name\"/" terraform/terraform.tfvars
        sed -i.bak "s/^create_dns_zone.*$/create_dns_zone     = true/" terraform/terraform.tfvars
        sed -i.bak "s/^enable_https.*$/enable_https        = true/" terraform/terraform.tfvars
        sed -i.bak "s/^tls_email.*$/tls_email           = \"$tls_email\"/" terraform/terraform.tfvars
        
        echo ""
        echo -e "${GREEN}✅ Configuration updated for automatic DNS management${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next steps:${NC}"
        echo "1. Run: terraform apply"
        echo "2. Get name servers: terraform output dns_zone_name_servers"
        echo "3. Configure name servers at your domain registrar"
        echo "4. Wait for DNS propagation (5-60 minutes)"
        echo "5. Access your app at: https://$app_host"
        ;;
        
    2)
        echo -e "${GREEN}🔧 Setting up external DNS management${NC}"
        echo ""
        
        read -p "Enter your app domain (e.g., 'webui.example.com'): " app_host
        read -p "Enter email for TLS certificates (e.g., 'admin@example.com'): " tls_email
        
        # Update terraform.tfvars
        sed -i.bak "s/^app_host.*$/app_host            = \"$app_host\"/" terraform/terraform.tfvars
        sed -i.bak "s/^create_dns_zone.*$/create_dns_zone     = false/" terraform/terraform.tfvars
        sed -i.bak "s/^enable_https.*$/enable_https        = true/" terraform/terraform.tfvars
        sed -i.bak "s/^tls_email.*$/tls_email           = \"$tls_email\"/" terraform/terraform.tfvars
        
        echo ""
        echo -e "${GREEN}✅ Configuration updated for external DNS management${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next steps:${NC}"
        echo "1. Run: terraform apply"
        echo "2. Get load balancer IP: terraform output ingress_ip"
        echo "3. Create A record: $app_host → [IP from step 2]"
        echo "4. Wait for DNS propagation"
        echo "5. Access your app at: https://$app_host"
        ;;
        
    3)
        echo -e "${GREEN}💻 Setting up development/local configuration${NC}"
        echo ""
        
        # Update terraform.tfvars for IP-based access
        sed -i.bak "s/^app_host.*$/app_host            = \"\"/" terraform/terraform.tfvars
        sed -i.bak "s/^create_dns_zone.*$/create_dns_zone     = false/" terraform/terraform.tfvars
        sed -i.bak "s/^enable_https.*$/enable_https        = false/" terraform/terraform.tfvars
        
        echo -e "${GREEN}✅ Configuration updated for IP-based access${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next steps:${NC}"
        echo "1. Run: terraform apply"
        echo "2. Get load balancer IP: terraform output ingress_ip"
        echo "3. Access your app at: http://[IP from step 2]"
        ;;
        
    4)
        echo -e "${YELLOW}❌ Skipping domain configuration${NC}"
        echo "You can configure domains later using this script."
        ;;
        
    *)
        echo -e "${RED}❌ Invalid option${NC}"
        exit 1
        ;;
esac

# Clean up backup files
rm -f terraform/terraform.tfvars.bak

echo ""
echo -e "${BLUE}🔧 Additional Configuration Available:${NC}"
echo ""
echo "📝 Edit terraform/terraform.tfvars for advanced settings:"
echo "  • DNS zone name"
echo "  • Custom annotations"
echo "  • Security settings"
echo ""
echo "📚 Read CUSTOM-DOMAIN-SETUP.md for detailed instructions"
echo ""
echo -e "${GREEN}🎉 Domain setup complete! Ready for deployment.${NC}"
