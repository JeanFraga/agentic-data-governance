# Secure Configuration Management

## Overview

This project now uses a secure configuration approach where sensitive values (OAuth secrets, credentials, etc.) are stored in a `.env` file that is **NOT committed to version control**.

## Configuration Files

### 1. Environment Variables (`.env`)
- **Purpose**: Store sensitive configuration values
- **Location**: Project root (`.env`)
- **Status**: ❌ **NOT COMMITTED** (in `.gitignore`)
- **Template**: `.env.example` (committed as reference)

### 2. Helm Values (`values-local.yaml`)
- **Purpose**: Helm chart configuration with placeholders
- **Status**: ✅ **COMMITTED** (no sensitive data)
- **Variables**: Uses `${VAR_NAME}` placeholders for environment variables

## Quick Start

### 1. Set Up Environment Variables
```bash
# Copy the example file
cp .env.example .env

# Edit with your actual values
nano .env
```

### 2. Verify Configuration
```bash
# Check that all variables are set
./check-env-simple.sh
```

### 3. Deploy Securely
```bash
# Deploy with environment variable substitution
./deploy-secure.sh
```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `OAUTH_CLIENT_ID` | Google OAuth 2.0 Client ID | `123456-abc.apps.googleusercontent.com` |
| `OAUTH_CLIENT_SECRET` | Google OAuth 2.0 Client Secret | `your-secret-value` |
| `GCP_PROJECT_ID` | Google Cloud Project ID | `my-project-123` |
| `GCLOUD_CREDENTIALS_PATH` | Path to gcloud credentials | `/Users/user/.config/gcloud` |
| `ADMIN_EMAIL` | Admin email address | `admin@example.com` |
| `SERVICE_NODE_PORT` | NodePort for OpenWebUI | `30080` |
| `OLLAMA_PROXY_PORT` | Port for Ollama proxy | `11434` |
| `ADK_BACKEND_PORT` | Port for ADK backend | `8000` |

## Security Benefits

### ✅ **What's Secure Now:**
1. **No secrets in Git**: Sensitive values are never committed
2. **Environment isolation**: Different `.env` files for different environments
3. **Template sharing**: `.env.example` provides structure without secrets
4. **Automated validation**: Scripts verify all required variables are set
5. **Masked output**: Scripts hide sensitive values in logs

### ❌ **What Was Insecure Before:**
1. OAuth secrets hardcoded in `values-local.yaml`
2. Credentials visible in Git history
3. Same values used across all environments
4. No validation of sensitive configuration

## File Structure

```
project/
├── .env                    # ❌ NOT COMMITTED (your actual secrets)
├── .env.example           # ✅ COMMITTED (template)
├── .gitignore             # ✅ Contains .env
├── deploy-secure.sh       # ✅ Secure deployment script
├── check-env-simple.sh    # ✅ Environment validation
└── webui-adk-chart/
    ├── values-local.yaml  # ✅ COMMITTED (uses ${VAR} placeholders)
    └── values.yaml        # ✅ COMMITTED (production template)
```

## Deployment Scripts

### `deploy-secure.sh`
- Loads `.env` file
- Validates all required variables
- Substitutes variables in Helm values
- Deploys with Helm

### `check-env-simple.sh`
- Verifies `.env` file exists
- Shows current configuration (masks secrets)
- Confirms readiness for deployment

## Best Practices

### For Development:
1. **Never commit `.env`** - Always in `.gitignore`
2. **Use `.env.example`** - Template for other developers
3. **Validate before deploy** - Run `./check-env-simple.sh`
4. **Use secure deployment** - Always use `./deploy-secure.sh`

### For Production:
1. **Environment-specific configs** - Different `.env` per environment
2. **Secret management** - Consider HashiCorp Vault, K8s secrets, etc.
3. **Access control** - Limit who can access production `.env`
4. **Rotation** - Regularly rotate OAuth secrets and credentials

## Migration from Hardcoded Values

If you previously had hardcoded values:

### 1. Create `.env` file:
```bash
cp .env.example .env
# Fill in your actual values
```

### 2. Update values files:
Replace hardcoded values with `${VAR_NAME}` placeholders

### 3. Use secure deployment:
```bash
./deploy-secure.sh
```

### 4. Verify no secrets in Git:
```bash
git log --all --full-history -- .env
# Should show no results
```

## Troubleshooting

### Missing `.env` file:
```bash
❌ Error: .env file not found
✅ Fix: cp .env.example .env && nano .env
```

### Missing variables:
```bash
❌ Error: Missing required environment variables
✅ Fix: Edit .env and set all required variables
```

### Deployment fails:
```bash
❌ Error: envsubst command not found
✅ Fix: Install gettext package
```

### Wrong values deployed:
```bash
❌ Issue: Old hardcoded values still used
✅ Fix: Ensure values file uses ${VAR} syntax
```

## Commands Reference

```bash
# Check environment
./check-env-simple.sh

# Deploy securely
./deploy-secure.sh

# Check deployment
kubectl get pods -n webui-adk-local

# View application
open http://localhost:30080
```

This approach ensures sensitive configuration is properly managed while maintaining a smooth development and deployment experience.
