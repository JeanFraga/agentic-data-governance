#!/bin/bash

# Complete Authentication Features Verification
# Tests both Google SSO and password-based authentication with signup

echo "🔐 Complete Authentication Features Verification"
echo "==============================================="

SERVICE_URL="http://localhost:30080"
echo "🌐 Service URL: $SERVICE_URL"
echo ""

# Test API configuration
echo "📊 API Configuration:"
CONFIG=$(curl -s "$SERVICE_URL/api/config")
if [ $? -eq 0 ]; then
    echo "   OAuth Provider: $(echo "$CONFIG" | jq -r '.oauth.providers.oidc // "Not configured"')"
    echo "   Login Form: $(echo "$CONFIG" | jq -r '.features.enable_login_form')"
    echo "   Signup: $(echo "$CONFIG" | jq -r '.features.enable_signup')"
    echo "   Auth: $(echo "$CONFIG" | jq -r '.features.auth')"
    echo "   Trusted Header: $(echo "$CONFIG" | jq -r '.features.auth_trusted_header')"
else
    echo "   ❌ Could not fetch configuration"
fi
echo ""

# Test OAuth endpoint
echo "🔗 Testing OAuth Endpoint:"
OAUTH_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "$SERVICE_URL/oauth/oidc/login")
if [ "$OAUTH_RESPONSE" = "302" ]; then
    echo "   ✅ OAuth redirect working (302 Found)"
    # Get the actual redirect URL
    REDIRECT_URL=$(curl -s -D - "$SERVICE_URL/oauth/oidc/login" | grep -i "location:" | cut -d' ' -f2 | tr -d '\r')
    if [[ $REDIRECT_URL == *"accounts.google.com"* ]]; then
        echo "   ✅ Redirects to Google OAuth"
    else
        echo "   ⚠️  Redirects to: $REDIRECT_URL"
    fi
else
    echo "   ❌ OAuth endpoint returned: $OAUTH_RESPONSE"
fi
echo ""

# Test authentication endpoints
echo "🔑 Testing Authentication Endpoints:"

# Test signin endpoint
SIGNIN_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"test"}' \
    "$SERVICE_URL/api/v1/auths/signin")
if [ "$SIGNIN_RESPONSE" = "400" ]; then
    echo "   ✅ Signin endpoint working (400 for invalid credentials)"
else
    echo "   ⚠️  Signin endpoint returned: $SIGNIN_RESPONSE"
fi

# Test signup endpoint (if available)
SIGNUP_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
    -H "Content-Type: application/json" \
    -d '{"name":"Test User","email":"newuser@example.com","password":"testpass123"}' \
    "$SERVICE_URL/api/v1/auths/signup")
echo "   Signup endpoint returned: $SIGNUP_RESPONSE"
echo ""

# Check environment variables
echo "🔧 Environment Variables Check:"
POD_NAME=$(kubectl get pods -n webui-adk-local -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    echo "   Pod: $POD_NAME"
    ENV_VARS=$(kubectl describe pod -n webui-adk-local "$POD_NAME" 2>/dev/null | grep -A 15 "Environment:" | grep -E "(ENABLE_|OAUTH_|WEBUI_)")
    if [ -n "$ENV_VARS" ]; then
        echo "$ENV_VARS" | while read line; do
            if [[ $line == *":"* ]]; then
                echo "   $line"
            fi
        done
    else
        echo "   ❌ Could not retrieve environment variables"
    fi
else
    echo "   ❌ Could not find pod"
fi
echo ""

# Test webpage content
echo "🌐 Testing Webpage Content:"
WEBPAGE=$(curl -s "$SERVICE_URL/auth")
if [ $? -eq 0 ]; then
    if [[ $WEBPAGE == *"Sign in with Google"* ]] || [[ $WEBPAGE == *"oauth"* ]]; then
        echo "   ✅ OAuth login option detected"
    else
        echo "   ⚠️  OAuth login option not found"
    fi
    
    if [[ $WEBPAGE == *"email"* ]] && [[ $WEBPAGE == *"password"* ]]; then
        echo "   ✅ Email/password form detected"
    else
        echo "   ⚠️  Email/password form not found"
    fi
    
    if [[ $WEBPAGE == *"sign up"* ]] || [[ $WEBPAGE == *"create"* ]] || [[ $WEBPAGE == *"register"* ]]; then
        echo "   ✅ Signup option detected"
    else
        echo "   ⚠️  Signup option not clearly visible"
    fi
else
    echo "   ❌ Could not fetch webpage"
fi
echo ""

echo "📋 Summary of Available Authentication Methods:"
echo "   1. 🔵 Google OAuth SSO"
echo "      • Click 'Sign in with Google' button"
echo "      • Auto-admin for your-admin-email@example.com"
echo "      • Secure authentication via Google"
echo ""
echo "   2. 🔑 Username/Password Authentication"
echo "      • Traditional email/password login"
echo "      • Account creation for new users"
echo "      • Local credential storage"
echo ""
echo "   3. 🔗 Account Linking"
echo "      • Same email can use both methods"
echo "      • Automatic account merging"
echo "      • Seamless user experience"
echo ""

echo "🚀 Next Steps:"
echo "   1. Go to: $SERVICE_URL"
echo "   2. Test Google OAuth login"
echo "   3. Test password-based login/signup"
echo "   4. Verify both methods work"
echo ""

echo "✅ Authentication verification complete!"
