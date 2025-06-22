# OpenWebUI Dual Authentication Configuration

## Overview

This configuration enables both **Google SSO (OAuth)** and **Username/Password** authentication methods in OpenWebUI, giving users flexibility in how they sign in.

## Authentication Methods Available

### 1. Google SSO (OAuth)
- **Provider**: Google OAuth 2.0
- **Auto-admin**: `your-admin-email@example.com` gets automatic admin privileges
- **Account merging**: Accounts are merged by email address
- **Button**: "Sign in with Google"

### 2. Username/Password
- **Traditional**: Email and password combination
- **Signup**: New users can create accounts
- **Admin creation**: Admin accounts can be created via SSO or password

## Current Configuration

### Environment Variables Set:
```bash
ENABLE_OAUTH_SIGNUP=True          # Enable Google OAuth signup
ENABLE_LOGIN_FORM=True            # Enable username/password login form
ENABLE_SIGNUP=True                # Allow new user registration
OAUTH_PROVIDER_NAME=Google        # OAuth provider name
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=True # Merge accounts by email
DEFAULT_ADMIN_EMAIL=your-admin-email@example.com # Auto-admin email
```

### OAuth Configuration:
- **Client ID**: `your-google-client-id.apps.googleusercontent.com`
- **Provider URL**: `https://accounts.google.com/.well-known/openid-configuration`
- **Scopes**: `openid email profile`
- **Redirect URI**: `http://localhost:30080/oauth/oidc/callback`

## User Experience

### Login Page Features:
1. **"Sign in with Google" button** - OAuth authentication
2. **Email/Password form** - Traditional authentication
3. **"Create account" link** - For new password-based users
4. **Account merging** - If same email used in both methods, accounts merge

### Admin Features:
- `your-admin-email@example.com` gets automatic admin privileges regardless of login method
- Admins can manage other users, configure settings, and access all features

## Testing Both Authentication Methods

### Test Google SSO:
1. Go to `http://localhost:30080`
2. Click "Sign in with Google"
3. Authenticate with Google account
4. Should be automatically logged in

### Test Password Authentication:
1. Go to `http://localhost:30080`
2. Use email/password form
3. If no account exists, click "Create account"
4. Register with email and password

## Configuration Files

### Helm Values (`values-local.yaml`):
```yaml
openWebUI:
  sso:
    enabled: true                    # Enable OAuth
    providerName: "Google"
  auth:
    disableSignup: false             # Allow new users
    enableOAuth: true               # Enable OAuth
    enablePasswordLogin: true       # Enable password login
  admin:
    email: "your-admin-email@example.com"
    autoCreate: true               # Auto-create admin
```

### Deployment Template:
```yaml
env:
  - name: ENABLE_OAUTH_SIGNUP
    value: "True"
  - name: ENABLE_LOGIN_FORM
    value: "True"                  # Always show password form
  - name: ENABLE_SIGNUP
    value: "True"
  - name: OAUTH_MERGE_ACCOUNTS_BY_EMAIL
    value: "True"
```

## Troubleshooting

### If Only OAuth Shows:
- Check `ENABLE_LOGIN_FORM=True` in pod environment
- Verify database settings don't override environment variables
- Restart pod if environment variables changed

### If Only Password Shows:
- Check OAuth client ID and secret are set
- Verify Google OAuth redirect URI is configured
- Check OAuth provider configuration

### If Signup is Disabled:
- Check `ENABLE_SIGNUP=True` in environment
- Verify admin hasn't disabled signup in settings
- Clear database and restart if needed

## Security Considerations

1. **OAuth Security**: Google handles authentication, reducing password security risks
2. **Account Merging**: Same email can use both authentication methods safely
3. **Admin Privileges**: Auto-admin only applies to specified email address
4. **Persistent Storage**: User data and settings are preserved across restarts

## Commands for Management

### Check Configuration:
```bash
curl -s http://localhost:30080/api/config | jq '.oauth, .features'
```

### View Environment Variables:
```bash
kubectl describe pod -n webui-adk-local [POD_NAME] | grep -A 20 "Environment:"
```

### Restart for Clean Initialization:
```bash
kubectl exec -n webui-adk-local [POD_NAME] -c open-webui -- rm -f /app/backend/data/webui.db
kubectl rollout restart deployment -n webui-adk-local webui-adk-local
```

### Test OAuth Endpoint:
```bash
curl -v "http://localhost:30080/oauth/oidc/login"
```

## Expected Behavior

Users should see both authentication options on the login page:
- Google OAuth button at the top
- Email/password form below
- "Create account" link for new users
- Seamless experience regardless of chosen method

The dual authentication setup provides flexibility while maintaining security and admin control.
