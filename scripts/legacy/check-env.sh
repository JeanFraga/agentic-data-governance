#!/bin/bash

# Environment Variables Verification Script
# Checks that all required environment variables are properly set

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo "🔍 Environment Variables Verification"
echo "====================================="

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    echo ""
    echo "To fix this:"
    echo "1. Copy the example file: cp .env.example .env"
    echo "2. Edit .env with your actual values"
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

echo "📂 Loading from: $ENV_FILE"
echo ""

# Define required variables and their descriptions
declare -A REQUIRED_VARS=(
    ["OAUTH_CLIENT_ID"]="Google OAuth 2.0 Client ID"
    ["OAUTH_CLIENT_SECRET"]="Google OAuth 2.0 Client Secret"
    ["GCP_PROJECT_ID"]="Google Cloud Project ID"
    ["GCLOUD_CREDENTIALS_PATH"]="Path to gcloud credentials"
    ["ADMIN_EMAIL"]="Admin email address"
    ["SERVICE_NODE_PORT"]="NodePort for OpenWebUI service"
    ["OLLAMA_PROXY_PORT"]="Port for Ollama proxy"
    ["ADK_BACKEND_PORT"]="Port for ADK backend"
)

echo "🔍 Checking required environment variables:"
ALL_VALID=true

for var in "${!REQUIRED_VARS[@]}"; do
    description="${REQUIRED_VARS[$var]}"
    var_value="${!var}"
    if [ -n "$var_value" ]; then
        # Mask sensitive values
        if [[ $var == *"SECRET"* ]] || [[ $var == *"KEY"* ]]; then
            masked_value="${var_value:0:8}..."
            echo "   ✅ $var: $masked_value ($description)"
        else
            echo "   ✅ $var: $var_value ($description)"
        fi
    else
        echo "   ❌ $var: NOT SET ($description)"
        ALL_VALID=false
    fi
done

echo ""

if [ "$ALL_VALID" = true ]; then
    echo "✅ All required environment variables are set!"
    echo ""
    echo "🚀 Ready to deploy with:"
    echo "   ./deploy-secure.sh"
else
    echo "❌ Some environment variables are missing."
    echo ""
    echo "To fix this:"
    echo "1. Edit your .env file"
    echo "2. Set all missing variables"
    echo "3. Run this script again to verify"
fi

echo ""
echo "📋 Current configuration will result in:"
echo "   • Service URL: http://localhost:${SERVICE_NODE_PORT:-30080}"
echo "   • OAuth Provider: Google"
echo "   • Admin Email: ${ADMIN_EMAIL:-'NOT SET'}"
echo "   • GCP Project: ${GCP_PROJECT_ID:-'NOT SET'}"
