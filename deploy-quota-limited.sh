#!/bin/bash

# Deploy with quota-limited configuration
# Use this script while waiting for CPU quota increase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Deploying with Quota-Limited Configuration${NC}"
echo -e "${YELLOW}📊 This uses minimal resource requests to fit within current quota${NC}"
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please copy .env.example to .env and configure your values"
    exit 1
fi

# Source environment variables
echo -e "${GREEN}📋 Loading environment variables...${NC}"
source .env

# Validate required environment variables
./check-env-simple.sh

echo -e "${GREEN}📝 Using quota-limited values file...${NC}"

# Export variables so envsubst can use them
export SERVICE_NODE_PORT
export OAUTH_CLIENT_ID
export OAUTH_CLIENT_SECRET
export ADMIN_EMAIL
export ADMIN_PASSWORD
export ADK_BACKEND_PORT
export GCP_PROJECT_ID
export GCLOUD_CREDENTIALS_PATH
export OLLAMA_PROXY_PORT

# Generate the final values file with variable substitution
echo -e "${GREEN}🔄 Generating Helm values with environment substitution...${NC}"
envsubst < webui-adk-chart/values-quota-limited.yaml > /tmp/values-quota-limited-final.yaml

echo -e "${GREEN}📋 Final values preview (sensitive values masked):${NC}"
cat /tmp/values-quota-limited-final.yaml | sed 's/password: .*/password: ***MASKED***/g' | sed 's/clientSecret: .*/clientSecret: ***MASKED***/g'

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: This is a quota-limited deployment${NC}"
echo -e "${YELLOW}   • Lower resource requests to fit within 24 CPU quota${NC}"
echo -e "${YELLOW}   • May have reduced performance${NC}"
echo -e "${YELLOW}   • Request quota increase for production workloads${NC}"
echo ""

read -p "Continue with quota-limited deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy using Helm with the quota-limited values
echo -e "${GREEN}🚀 Deploying with Helm...${NC}"
helm upgrade --install webui-adk-local ./webui-adk-chart \
    --values /tmp/values-quota-limited-final.yaml \
    --create-namespace \
    --namespace webui-adk \
    --wait \
    --timeout 10m

# Clean up temporary file
rm -f /tmp/values-quota-limited-final.yaml

echo ""
echo -e "${GREEN}✅ Quota-limited deployment completed!${NC}"
echo ""

# Check pod status
echo -e "${GREEN}📊 Checking pod status...${NC}"
kubectl get pods -n webui-adk

echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Monitor pod startup: kubectl get pods -n webui-adk -w"
echo "2. Check logs if needed: kubectl logs -n webui-adk -l app=webui-adk-local -f"
echo "3. Request CPU quota increase using QUOTA-INCREASE-GUIDE.md"
echo "4. Once quota increased, redeploy with full resources using deploy-secure.sh"
echo ""
echo -e "${GREEN}🎉 Access your application via NodePort on the configured port!${NC}"
