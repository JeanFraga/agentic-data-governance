#!/bin/bash

# OAuth Configuration Update Instructions

echo "🔧 OAuth Configuration Update Required"
echo "======================================="
echo ""
echo "Your OAuth Client ID needs to be updated with the new redirect URIs:"
echo ""
echo "Client ID: 112698224261-ktmjfk2fnhkj0ksjelcuo2gn23jqk8fi.apps.googleusercontent.com"
echo ""
echo "Required Redirect URIs:"
echo "1. https://agenticdatagovernance.com/oauth/oidc/callback"
echo "2. http://localhost:30080/oauth/oidc/callback"
echo ""
echo "Steps to update:"
echo "1. Go to: https://console.cloud.google.com/apis/credentials"
echo "2. Click on your OAuth 2.0 Client ID"
echo "3. Add the redirect URIs above"
echo "4. Save the changes"
echo ""
echo "✅ Once updated, you can proceed with the production deployment."
