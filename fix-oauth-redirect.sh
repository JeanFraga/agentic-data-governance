#!/bin/bash

# Fix OAuth Redirect URI Configuration
# This script helps identify and fix OAuth redirect URI mismatches

echo "🔧 OAuth Redirect URI Configuration Fix"
echo "======================================="

# Get current configuration
CURRENT_URL=$(curl -s -I "http://localhost:30080/oauth/oidc/login" | grep -i location | cut -d' ' -f2 | tr -d '\r')
if [ -n "$CURRENT_URL" ]; then
    REDIRECT_URI=$(echo "$CURRENT_URL" | grep -o 'redirect_uri=[^&]*' | cut -d'=' -f2 | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
    CLIENT_ID=$(echo "$CURRENT_URL" | grep -o 'client_id=[^&]*' | cut -d'=' -f2)
    
    echo "📋 Current Configuration:"
    echo "   Client ID: $CLIENT_ID"
    echo "   Redirect URI: $REDIRECT_URI"
    echo ""
else
    echo "❌ Could not retrieve OAuth configuration. Make sure the service is running."
    exit 1
fi

echo "🔗 Required Redirect URIs for Google Cloud Console:"
echo "   Add these to your OAuth 2.0 Client configuration:"
echo "   → http://localhost:30080/oauth/oidc/callback"
echo "   → http://127.0.0.1:30080/oauth/oidc/callback"
echo ""

echo "📝 Steps to Fix:"
echo "1. Go to: https://console.cloud.google.com/apis/credentials"
echo "2. Select project: your-gcp-project-id"
echo "3. Find OAuth 2.0 client: $CLIENT_ID"
echo "4. Click 'Edit' and add the redirect URIs above"
echo "5. Save the changes"
echo ""

echo "🧪 Test OAuth after fixing:"
echo "   curl -i 'http://localhost:30080/oauth/oidc/login'"
echo ""

echo "🌐 Or test in browser:"
echo "   http://localhost:30080"
echo ""

echo "✅ Configuration fix complete!"
