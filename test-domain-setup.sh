#!/bin/bash

# Test Domain Setup Script
# This script validates your domain configuration before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Domain Setup Validation${NC}"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform/terraform.tfvars not found${NC}"
    echo "Run ./setup-domain.sh first to configure your domain settings"
    exit 1
fi

# Extract configuration from terraform.tfvars
app_host=$(grep "^app_host" terraform/terraform.tfvars | cut -d'"' -f2)
domain_name=$(grep "^domain_name" terraform/terraform.tfvars | cut -d'"' -f2 || echo "")
create_dns_zone=$(grep "^create_dns_zone" terraform/terraform.tfvars | grep -o 'true\|false' || echo "false")
enable_https=$(grep "^enable_https" terraform/terraform.tfvars | grep -o 'true\|false' || echo "false")
tls_email=$(grep "^tls_email" terraform/terraform.tfvars | cut -d'"' -f2 || echo "")

echo -e "${GREEN}📋 Current Configuration:${NC}"
echo "  App Host: $app_host"
echo "  Domain Name: $domain_name"
echo "  DNS Management: $create_dns_zone"
echo "  HTTPS Enabled: $enable_https"
echo "  TLS Email: $tls_email"
echo ""

# Validation checks
errors=0

# Check app_host
if [ -z "$app_host" ] || [ "$app_host" == "webui.your-domain.com" ]; then
    echo -e "${YELLOW}⚠️  Warning: app_host not configured or using placeholder${NC}"
    ((errors++))
else
    echo -e "${GREEN}✅ App host configured: $app_host${NC}"
fi

# Check domain configuration consistency
if [ "$create_dns_zone" == "true" ]; then
    if [ -z "$domain_name" ] || [ "$domain_name" == "your-domain.com" ]; then
        echo -e "${RED}❌ Error: create_dns_zone is true but domain_name is not configured${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ DNS zone configuration looks good${NC}"
    fi
fi

# Check HTTPS configuration
if [ "$enable_https" == "true" ]; then
    if [ -z "$tls_email" ] || [ "$tls_email" == "admin@your-domain.com" ]; then
        echo -e "${YELLOW}⚠️  Warning: HTTPS enabled but TLS email not configured${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ HTTPS configuration looks good${NC}"
    fi
fi

# Check Terraform syntax
echo ""
echo -e "${BLUE}🔍 Validating Terraform configuration...${NC}"
cd terraform
if terraform validate >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Terraform configuration is valid${NC}"
else
    echo -e "${RED}❌ Terraform configuration has errors${NC}"
    terraform validate
    ((errors++))
fi
cd ..

# DNS checks (if domain is configured)
if [ "$app_host" != "webui.your-domain.com" ] && [ -n "$app_host" ]; then
    echo ""
    echo -e "${BLUE}🌐 DNS Resolution Check...${NC}"
    
    if nslookup "$app_host" >/dev/null 2>&1; then
        current_ip=$(nslookup "$app_host" | grep -A1 "Name:" | tail -n1 | awk '{print $2}')
        echo -e "${GREEN}✅ Domain resolves to: $current_ip${NC}"
        
        # Check if it's pointing to Google Cloud
        if echo "$current_ip" | grep -E "^(34|35)\." >/dev/null; then
            echo -e "${GREEN}✅ Appears to be pointing to Google Cloud${NC}"
        else
            echo -e "${YELLOW}⚠️  Domain not pointing to Google Cloud (may be intentional)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Domain does not resolve yet (expected for new setups)${NC}"
    fi
fi

echo ""
echo -e "${BLUE}📊 Validation Summary:${NC}"

if [ $errors -eq 0 ]; then
    echo -e "${GREEN}🎉 Configuration looks good! Ready for deployment.${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. Run: cd terraform && terraform plan"
    echo "2. Review the plan carefully"
    echo "3. Deploy: terraform apply"
    echo ""
    if [ "$create_dns_zone" == "true" ]; then
        echo "4. Configure name servers at your domain registrar"
        echo "5. Wait for DNS propagation"
    fi
    echo ""
    echo -e "${GREEN}🌐 Your app will be available at:${NC}"
    if [ "$enable_https" == "true" ]; then
        echo "   https://$app_host"
    else
        echo "   http://$app_host"
    fi
else
    echo -e "${RED}❌ Found $errors configuration issue(s)${NC}"
    echo ""
    echo -e "${YELLOW}🔧 To fix issues:${NC}"
    echo "1. Run ./setup-domain.sh to reconfigure"
    echo "2. Edit terraform/terraform.tfvars manually"
    echo "3. Run this script again to validate"
fi

echo ""
echo -e "${BLUE}📚 For detailed setup instructions, see:${NC}"
echo "  CUSTOM-DOMAIN-SETUP.md"
