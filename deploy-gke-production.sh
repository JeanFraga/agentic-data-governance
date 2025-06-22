#!/bin/bash

# Deploy full application to GKE with production configuration
# This script deploys OpenWebUI + ADK Backend + Ollama Proxy to GKE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying ADK Application to GKE${NC}"
echo -e "${BLUE}📊 Full production deployment with all services${NC}"
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Please copy .env.example to .env and configure your values"
    exit 1
fi

# Source environment variables
echo -e "${GREEN}📋 Loading environment variables...${NC}"
set -a  # Automatically export all variables
source .env
set +a  # Stop auto-exporting

# Set default values for optional variables
export APP_HOST="${APP_HOST:-app.agenticdatagovernance.com}"
export ENABLE_TLS="${ENABLE_TLS:-true}"

# Validate required environment variables
echo -e "${GREEN}🔍 Validating environment variables...${NC}"
./check-env-simple.sh

echo -e "${GREEN}📝 Using GKE production values file...${NC}"

# Substitute environment variables in values file
echo -e "${GREEN}🔄 Generating Helm values with environment substitution...${NC}"
VALUES_FILE="webui-adk-chart/values-gke-production.yaml"
TEMP_VALUES="/tmp/webui-adk-values.yaml"

# Use envsubst to replace environment variables
envsubst < "$VALUES_FILE" > "$TEMP_VALUES"

# Debug: Check if key variables are set
echo -e "${BLUE}🔍 Debug - Environment variables:${NC}"
echo "OAUTH_CLIENT_ID: ${OAUTH_CLIENT_ID:0:20}..."
echo "ADK_BACKEND_PORT: ${ADK_BACKEND_PORT}"
echo "OLLAMA_PROXY_PORT: ${OLLAMA_PROXY_PORT}"

echo -e "${GREEN}📋 Final values preview (sensitive values masked):${NC}"
# Show the values file with sensitive values masked
sed -e 's/clientSecret: ".*"/clientSecret: ***MASKED***/' \
    -e 's/password: ".*"/password: ***MASKED***/' \
    "$TEMP_VALUES" | head -50

echo ""
echo -e "${YELLOW}⚠️  PRODUCTION DEPLOYMENT DETAILS:${NC}"
echo -e "   • Deploying to: ${APP_HOST}"
echo -e "   • TLS enabled: ${ENABLE_TLS}"
echo -e "   • Admin email: ${ADMIN_EMAIL}"
echo -e "   • Using Artifact Registry images"
echo -e "   • No local credentials mounting (using GKE service account)"
echo ""

read -p "Continue with production deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🚫 Deployment cancelled${NC}"
    exit 1
fi

echo -e "${GREEN}🚀 Deploying with Helm...${NC}"

# Deploy the application
helm upgrade --install webui-adk-prod ./webui-adk-chart \
    --values "$TEMP_VALUES" \
    --set oauth.clientSecret="$OAUTH_CLIENT_SECRET" \
    --timeout 10m \
    --wait

# Clean up temporary file
rm -f "$TEMP_VALUES"

echo ""
echo -e "${GREEN}✅ Deployment completed!${NC}"
echo ""

# Check deployment status
echo -e "${BLUE}📊 Checking deployment status...${NC}"
echo ""

# Wait a moment for resources to be created
sleep 5

echo -e "${GREEN}🔍 Pod Status:${NC}"
kubectl get pods -l app.kubernetes.io/name=webui-adk-chart -o wide

echo ""
echo -e "${GREEN}🔍 Service Status:${NC}"
kubectl get services -l app.kubernetes.io/name=webui-adk-chart

echo ""
echo -e "${GREEN}🔍 Ingress Status:${NC}"
kubectl get ingress

echo ""
echo -e "${GREEN}📋 Access Information:${NC}"
echo -e "   • Application URL: https://${APP_HOST}"
echo -e "   • Ingress IP: $(kubectl get ingress webui-adk-prod-webui-adk-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo 'Pending...')"
echo -e "   • Admin Email: ${ADMIN_EMAIL}"
echo ""
echo -e "${YELLOW}📝 Note: DNS propagation and TLS certificate provisioning may take a few minutes${NC}"
echo ""
echo -e "${BLUE}🔧 To check logs:${NC}"
echo -e "   kubectl logs -l app.kubernetes.io/name=webui-adk-chart -c openwebui"
echo -e "   kubectl logs -l app.kubernetes.io/name=webui-adk-chart -c adk-backend"
echo -e "   kubectl logs -l app.kubernetes.io/name=webui-adk-chart -c ollama-proxy"
echo ""
echo -e "${BLUE}🛑 To clean up:${NC}"
echo -e "   helm uninstall webui-adk-prod"
echo ""
