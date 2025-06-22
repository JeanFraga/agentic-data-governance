# OpenWebUI SSO Configuration Guide

## Overview

This configuration automatically creates an admin account for `your-admin-email@example.com` and enables Google Single Sign-On (SSO) authentication without requiring passwords.

## Features

✅ **Automatic Admin Account**: Creates admin account for `your-admin-email@example.com`  
✅ **Google SSO**: Authentication via Google OAuth  
✅ **No Passwords**: Users authenticate only through Google  
✅ **Auto-Registration**: New users can sign up via SSO  
✅ **Account Merging**: Merges accounts by email address  

## Google OAuth Setup

### 1. Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services > Credentials**
3. Click **+ CREATE CREDENTIALS > OAuth 2.0 Client IDs**
4. Configure the OAuth consent screen if not already done
5. Choose **Web application** as application type
6. Set the following:

**Name**: `OpenWebUI SSO`

**Authorized JavaScript origins**:
```
http://localhost:30080              # For local development
https://webui.your-domain.com       # For production
```

**Authorized redirect URIs**:
```
http://localhost:30080/oauth/google/callback              # Local
https://webui.your-domain.com/oauth/google/callback       # Production
```

### 2. Configure OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen**
2. Set **User Type**: External (for testing) or Internal (for organization)
3. Fill in required fields:
   - **App name**: `OpenWebUI ADK`
   - **User support email**: `your-support-email@example.com`
   - **Developer contact**: `your-developer-email@example.com`
4. Add **Scopes**:
   - `openid`
   - `email` 
   - `profile`
5. Add **Test users** (if External):
   - `your-admin-email@example.com`

## Configuration Files

### Production Configuration (`values.yaml`)

```yaml
openWebUI:
  sso:
    enabled: true
    clientId: "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    clientSecret: "YOUR_GOOGLE_CLIENT_SECRET"
    providerUrl: "https://accounts.google.com/.well-known/openid-configuration"
    providerName: "Google"
    scopes: "openid email profile"
  admin:
    email: "your-admin-email@example.com"
    autoCreate: true
  auth:
    disableSignup: false
    enableOAuth: true
    requireEmailVerification: false
```

### Local Development Configuration (`values-local.yaml`)

```yaml
openWebUI:
  sso:
    enabled: true
    clientId: "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    clientSecret: "YOUR_GOOGLE_CLIENT_SECRET"
    providerUrl: "https://accounts.google.com/.well-known/openid-configuration"
    providerName: "Google"
    scopes: "openid email profile"
  admin:
    email: "your-admin-email@example.com"
    autoCreate: true
  auth:
    disableSignup: false
    enableOAuth: true
    requireEmailVerification: false
```

## Environment Variables Set by Configuration

The Helm chart automatically configures these OpenWebUI environment variables:

```bash
# OAuth Configuration
ENABLE_OAUTH_SIGNUP=True
OAUTH_PROVIDER_NAME=Google
OPENID_PROVIDER_URL=https://accounts.google.com/.well-known/openid-configuration
OAUTH_SCOPES=openid email profile
OAUTH_CLIENT_ID=<from-secret>
OAUTH_CLIENT_SECRET=<from-secret>

# Admin Account Auto-Creation
DEFAULT_USER_ROLE=admin
DEFAULT_ADMIN_EMAIL=your-admin-email@example.com

# Authentication Settings
ENABLE_SIGNUP=True
ENABLE_LOGIN_FORM=False  # Disable password login
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=True
```

## Deployment Steps

### 1. Update OAuth Credentials

**For Local Development:**
```bash
# Edit values-local.yaml
vim webui-adk-chart/values-local.yaml

# Update these lines:
clientId: "your-actual-google-client-id.apps.googleusercontent.com"
clientSecret: "your-actual-google-client-secret"
```

**For Production (Terraform):**
```bash
# Edit terraform.tfvars
vim terraform/terraform.tfvars

# Update these lines:
oauth_client_id     = "your-actual-google-client-id.apps.googleusercontent.com"
oauth_client_secret = "your-actual-google-client-secret"
```

### 2. Deploy/Upgrade

**Local Deployment:**
```bash
helm upgrade webui-adk-local ./webui-adk-chart \
  -f webui-adk-chart/values-local.yaml \
  -n webui-adk-local
```

**Production Deployment:**
```bash
# Phase 2 of Terraform deployment
cd terraform
terraform apply  # With deploy_kubernetes_resources = true
```

### 3. Access OpenWebUI

**Local**: http://localhost:30080  
**Production**: https://webui.your-domain.com

## User Experience

### First Time Login (your-admin-email@example.com)

1. User navigates to OpenWebUI
2. Clicks "Sign in with Google" 
3. Authenticates with Google
4. **Automatically gets admin privileges**
5. No password required, ever!

### Other Users

1. Navigate to OpenWebUI
2. Click "Sign in with Google"
3. Authenticate with Google
4. **Account automatically created** with default user role
5. Can start using the application immediately

## Security Features

- **No Password Storage**: All authentication handled by Google
- **Trusted Email Headers**: Secure email verification
- **Account Merging**: Prevents duplicate accounts
- **Admin Auto-Creation**: Ensures admin access on first deploy

## Troubleshooting

### Common Issues

**Issue**: "OAuth error: invalid_client"  
**Solution**: Check OAuth client ID and secret are correct in values file

**Issue**: "Redirect URI mismatch"  
**Solution**: Ensure redirect URIs in Google Console match your domain exactly

**Issue**: "Admin account not created"  
**Solution**: Check `DEFAULT_ADMIN_EMAIL` environment variable is set correctly

**Issue**: "Users can't sign up"  
**Solution**: Verify `ENABLE_OAUTH_SIGNUP=True` and OAuth consent screen is published

### Verification Commands

```bash
# Check environment variables
kubectl exec -n webui-adk-local deployment/webui-adk-local -c open-webui -- env | grep OAUTH

# Check secret
kubectl get secret webui-adk-local-oidc-secret -n webui-adk-local -o yaml

# Check pod logs
kubectl logs -n webui-adk-local deployment/webui-adk-local -c open-webui
```

### OAuth Consent Screen Status

Make sure your OAuth consent screen is **Published** (not in Testing mode) for production use.

## Next Steps

1. ✅ Set up Google OAuth credentials
2. ✅ Update configuration files with real credentials  
3. ✅ Deploy/upgrade the application
4. ✅ Test SSO login with `your-admin-email@example.com`
5. ✅ Verify admin privileges are assigned
6. ✅ Test with other Google accounts

Your OpenWebUI will now automatically create an admin account for `your-admin-email@example.com` and enable passwordless Google SSO! 🎉
