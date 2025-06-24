#!/bin/bash

# Secure Helm Deployment Script
# This script loads sensitive values from .env file and deploys the chart

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
CHART_DIR="$SCRIPT_DIR/webui-adk-chart"
VALUES_FILE="$CHART_DIR/values-local.yaml"

echo "🔐 Secure Helm Deployment for webui-adk-chart"
echo "=============================================="

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    echo "Please copy .env.example to .env and fill in your values:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your actual values"
    exit 1
fi

# Load environment variables from .env file
echo "📂 Loading environment variables from .env..."
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a

# Validate required environment variables
REQUIRED_VARS=(
    "OAUTH_CLIENT_ID"
    "OAUTH_CLIENT_SECRET"
    "GCP_PROJECT_ID"
    "GCLOUD_CREDENTIALS_PATH"
    "ADMIN_EMAIL"
    "SERVICE_NODE_PORT"
    "OLLAMA_PROXY_PORT"
    "ADK_BACKEND_PORT"
)

echo "🔍 Validating required environment variables..."
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    else
        echo "   ✅ $var is set"
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "❌ Error: Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo "Please check your .env file and ensure all variables are set."
    exit 1
fi

# Check if chart directory exists
if [ ! -d "$CHART_DIR" ]; then
    echo "❌ Error: Chart directory not found at $CHART_DIR"
    exit 1
fi

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: Values file not found at $VALUES_FILE"
    exit 1
fi

echo ""
echo "🚀 Deploying Helm chart with secure configuration..."
echo "   Chart: $CHART_DIR"
echo "   Values: $VALUES_FILE"
echo "   Namespace: webui-adk-local"
echo ""

# Substitute environment variables in values file and deploy
envsubst < "$VALUES_FILE" | helm upgrade webui-adk-local "$CHART_DIR" \
    --install \
    --create-namespace \
    --namespace webui-adk-local \
    --values -

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   • Release: webui-adk-local"
    echo "   • Namespace: webui-adk-local"
    echo "   • OAuth Client: ${OAUTH_CLIENT_ID}"
    echo "   • Admin Email: ${ADMIN_EMAIL}"
    echo "   • Service URL: http://localhost:${SERVICE_NODE_PORT}"
    echo ""
    echo "🔍 Check deployment status:"
    echo "   kubectl get pods -n webui-adk-local"
    echo "   kubectl get svc -n webui-adk-local"
    echo ""
    echo "🌐 Access the application:"
    echo "   http://localhost:${SERVICE_NODE_PORT}"
else
    echo "❌ Deployment failed!"
    exit 1
fi
