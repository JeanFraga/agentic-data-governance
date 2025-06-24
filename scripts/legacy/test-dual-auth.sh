#!/bin/bash

# Test Dual Authentication Configuration
echo "🔐 Testing Dual Authentication Configuration"
echo "=========================================="

echo ""
echo "🌐 Service URL: http://localhost:30080"
echo ""

echo "📊 Current Configuration:"
CONFIG=$(curl -s http://localhost:30080/api/config)
echo "   OAuth Enabled: $(echo $CONFIG | jq -r '.oauth.providers.oidc // "Not configured"')"
echo "   Login Form: $(echo $CONFIG | jq -r '.features.enable_login_form')"
echo "   Signup: $(echo $CONFIG | jq -r '.features.enable_signup')"
echo ""

echo "🔍 Environment Variables in Pod:"
POD_NAME=$(kubectl get pods -n webui-adk-local -o jsonpath='{.items[0].metadata.name}')
echo "   Pod: $POD_NAME"

ENV_VARS=$(kubectl describe pod -n webui-adk-local $POD_NAME | grep -A 15 "Environment:" | grep -E "(ENABLE_|OAUTH_|DEFAULT_)" | head -10)
echo "$ENV_VARS" | while read line; do
    echo "   $line"
done

echo ""
echo "🔗 Testing OAuth Endpoint:"
OAUTH_RESPONSE=$(curl -s -I "http://localhost:30080/oauth/oidc/login" | grep -i "location" | head -1)
if [[ $OAUTH_RESPONSE == *"google"* ]]; then
    echo "   ✅ OAuth redirect to Google working"
else
    echo "   ❌ OAuth redirect not working"
fi

echo ""
echo "🧪 Testing Authentication Methods:"
echo ""
echo "1. 🔵 Google SSO Test:"
echo "   → Go to: http://localhost:30080"
echo "   → Look for 'Sign in with Google' button"
echo "   → Click it and authenticate with Google"
echo ""
echo "2. 🔑 Password Authentication Test:"
echo "   → Go to: http://localhost:30080"
echo "   → Look for email/password form"
echo "   → Try to sign in or create account"
echo ""

if [[ $(echo $CONFIG | jq -r '.features.enable_signup') == "false" ]]; then
    echo "⚠️  Note: Signup appears disabled in database settings."
    echo "   This might be overridden by admin configuration."
    echo "   Environment variables show ENABLE_SIGNUP=True"
    echo ""
    echo "💡 To force signup enabled, you can:"
    echo "   1. Delete database: kubectl exec -n webui-adk-local $POD_NAME -c open-webui -- rm -f /app/backend/data/webui.db"
    echo "   2. Restart pod: kubectl rollout restart deployment -n webui-adk-local webui-adk-local"
    echo ""
fi

echo "🎯 Expected Results:"
echo "   ✅ Both Google OAuth and password login should be available"
echo "   ✅ Users should be able to create accounts (if signup enabled)"
echo "   ✅ your-admin-email@example.com gets automatic admin privileges"
echo "   ✅ Accounts with same email can use both authentication methods"
echo ""

echo "📋 Current Status Summary:"
echo "   • OAuth Provider: $(echo $CONFIG | jq -r '.oauth.providers.oidc // "None"')"
echo "   • Login Form: $(echo $CONFIG | jq -r '.features.enable_login_form')"
echo "   • Signup: $(echo $CONFIG | jq -r '.features.enable_signup')"
echo "   • Environment ENABLE_SIGNUP: $(kubectl describe pod -n webui-adk-local $POD_NAME | grep "ENABLE_SIGNUP:" | awk '{print $2}')"

echo ""
echo "🚀 Test the application now at: http://localhost:30080"
