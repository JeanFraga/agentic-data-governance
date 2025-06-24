#!/bin/bash

# OpenWebUI OAuth Configuration Helper Script
# This script helps configure Google OAuth for OpenWebUI SSO

set -e

echo "🔧 OpenWebUI Google OAuth Configuration Helper"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}📋 Configuration Information:${NC}"
echo "   • Admin Email: your-admin-email@example.com"
echo "   • Provider: Google OAuth 2.0"
echo "   • Auto-create admin account: YES"
echo "   • Password login: DISABLED"
echo ""

# Check if we're in the right directory
if [[ ! -f "webui-adk-chart/values-local.yaml" ]]; then
    echo -e "${RED}❌ Error: Please run this script from the project root directory${NC}"
    echo "   Expected to find: webui-adk-chart/values-local.yaml"
    exit 1
fi

echo -e "${YELLOW}📝 Please follow these steps:${NC}"
echo ""
echo "1. Go to Google Cloud Console: https://console.cloud.google.com"
echo "2. Navigate to APIs & Services > Credentials"
echo "3. Create OAuth 2.0 Client ID (Web application)"
echo "4. Configure redirect URIs:"
echo "   • http://localhost:30080/oauth/google/callback (local)"
echo "   • https://webui.your-domain.com/oauth/google/callback (production)"
echo ""

# Prompt for OAuth credentials
echo -e "${BLUE}🔑 Enter your Google OAuth credentials:${NC}"
echo ""

read -p "Enter Google OAuth Client ID: " CLIENT_ID
if [[ -z "$CLIENT_ID" ]]; then
    echo -e "${RED}❌ Client ID cannot be empty${NC}"
    exit 1
fi

read -s -p "Enter Google OAuth Client Secret: " CLIENT_SECRET
echo ""
if [[ -z "$CLIENT_SECRET" ]]; then
    echo -e "${RED}❌ Client Secret cannot be empty${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🔄 Updating configuration files...${NC}"

# Update values-local.yaml
echo "   • Updating webui-adk-chart/values-local.yaml"
sed -i.bak "s|clientId:.*|clientId: \"$CLIENT_ID\"|g" webui-adk-chart/values-local.yaml
sed -i.bak "s|clientSecret:.*|clientSecret: \"$CLIENT_SECRET\"|g" webui-adk-chart/values-local.yaml

# Update terraform.tfvars if it exists
if [[ -f "terraform/terraform.tfvars" ]]; then
    echo "   • Updating terraform/terraform.tfvars"
    sed -i.bak "s|oauth_client_id.*=.*|oauth_client_id     = \"$CLIENT_ID\"|g" terraform/terraform.tfvars
    sed -i.bak "s|oauth_client_secret.*=.*|oauth_client_secret = \"$CLIENT_SECRET\"|g" terraform/terraform.tfvars
fi

echo ""
echo -e "${GREEN}✅ Configuration updated successfully!${NC}"
echo ""

# Check current deployment status
echo -e "${BLUE}📊 Checking current deployment status...${NC}"

if kubectl get namespace webui-adk-local >/dev/null 2>&1; then
    echo "   • Namespace webui-adk-local exists"
    
    if kubectl get deployment webui-adk-local -n webui-adk-local >/dev/null 2>&1; then
        echo "   • Deployment webui-adk-local exists"
        echo ""
        echo -e "${YELLOW}🚀 Ready to upgrade deployment!${NC}"
        echo ""
        echo "Run this command to apply the SSO configuration:"
        echo -e "${GREEN}helm upgrade webui-adk-local ./webui-adk-chart -f webui-adk-chart/values-local.yaml -n webui-adk-local${NC}"
    else
        echo "   • No existing deployment found"
        echo ""
        echo -e "${YELLOW}🚀 Ready to deploy!${NC}"
        echo ""
        echo "Run this command to deploy with SSO configuration:"
        echo -e "${GREEN}helm install webui-adk-local ./webui-adk-chart -f webui-adk-chart/values-local.yaml -n webui-adk-local --create-namespace${NC}"
    fi
else
    echo "   • Namespace webui-adk-local does not exist"
    echo ""
    echo -e "${YELLOW}🚀 Ready to deploy!${NC}"
    echo ""
    echo "Run this command to deploy with SSO configuration:"
    echo -e "${GREEN}helm install webui-adk-local ./webui-adk-chart -f webui-adk-chart/values-local.yaml -n webui-adk-local --create-namespace${NC}"
fi

echo ""
echo -e "${BLUE}🌐 After deployment, access OpenWebUI at:${NC}"
echo "   • Local: http://localhost:30080"
echo "   • Login will redirect to Google OAuth"
echo "   • your-admin-email@example.com will have admin privileges"
echo ""

echo -e "${YELLOW}📚 For more information, see:${NC}"
echo "   • OPENWEBUI-SSO-CONFIG.md - Complete setup guide"
echo "   • TERRAFORM-DEPLOYMENT.md - Production deployment"
echo ""

# Clean up backup files
rm -f webui-adk-chart/values-local.yaml.bak terraform/terraform.tfvars.bak 2>/dev/null || true

echo -e "${GREEN}🎉 Configuration complete! You're ready to deploy OpenWebUI with Google SSO.${NC}"
