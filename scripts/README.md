# Agentic Data Governance - Scripts Directory

This directory contains the unified management system for the Agentic Data Governance project. The individual scripts have been **consolidated into a single, powerful management tool** that automates deployment, configuration, testing, and troubleshooting tasks.

## 🚀 **NEW: Cloud Build Integration**

The management system now uses **Google Cloud Build** by default for production deployments, providing:
- ✅ **Faster builds** - No local Docker daemon required
- 🔒 **Enhanced security** - Builds in Google's secure environment  
- 📊 **Centralized logging** - Build logs in Google Cloud Console
- 🌐 **Consistent environment** - Same build environment for all developers
- 💾 **Resource efficient** - No local CPU/disk usage

### Build Options
```bash
# Default: Cloud Build (recommended)
./adk-mgmt.sh build images

# Explicit Cloud Build
./adk-mgmt.sh build cloudbuild  

# Legacy local Docker (deprecated)
./adk-mgmt.sh build legacy
```

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Unified Commands](#unified-commands)
- [Migration from Legacy Scripts](#migration-from-legacy-scripts)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## ⚡ Quick Start

### Using the Unified Script

```bash
# Check environment
./scripts/adk-mgmt.sh env check

# Deploy locally
./scripts/adk-mgmt.sh deploy local

# Test everything
./scripts/adk-mgmt.sh test all

# Show status
./scripts/adk-mgmt.sh status
```

### Using the Convenience Wrapper

```bash
# Same commands, shorter syntax
./run-script.sh env check
./run-script.sh deploy local
./run-script.sh test all
./run-script.sh status
```

## 🎯 Unified Commands

### 📋 Environment & Setup
```bash
./adk-mgmt.sh env check              # Check environment variables
./adk-mgmt.sh env setup              # Interactive environment setup
./adk-mgmt.sh domain setup           # Configure custom domain
./adk-mgmt.sh dns setup              # Set up DNS configuration
./adk-mgmt.sh oauth setup            # Configure OAuth settings
```

### 🚀 Deployment
```bash
# Image Building (Cloud Build)
./adk-mgmt.sh build images           # Build using Cloud Build (default)
./adk-mgmt.sh build cloudbuild       # Build using Cloud Build (explicit)
./adk-mgmt.sh build legacy           # Build using local Docker (deprecated)

# Environment Deployment
./adk-mgmt.sh deploy local           # Deploy to local/development
./adk-mgmt.sh deploy production      # Deploy to GKE production (includes Cloud Build)
./adk-mgmt.sh deploy quick           # Quick deployment with auto-setup
./adk-mgmt.sh deploy quota-limited   # Deploy with minimal resources

# Destruction
./adk-mgmt.sh destroy local          # Destroy local deployment
./adk-mgmt.sh destroy production     # Destroy production deployment
```

### 🧪 Testing & Validation
```bash
./adk-mgmt.sh test all               # Run comprehensive test suite
./adk-mgmt.sh test auth              # Test authentication features
./adk-mgmt.sh test dns               # Test DNS configuration
./adk-mgmt.sh test domain            # Test domain setup
./adk-mgmt.sh test connectivity      # Test network connectivity
```

### � Status & Info
```bash
./adk-mgmt.sh status                 # Show deployment status
./adk-mgmt.sh logs [service]         # Show logs for service
./adk-mgmt.sh info                   # Show connection information
./adk-mgmt.sh resources              # Show resource usage
```

### 🔧 Management
```bash
./adk-mgmt.sh restart [service]      # Restart service(s)
./adk-mgmt.sh scale <replicas>       # Scale deployment
./adk-mgmt.sh upgrade                # Upgrade deployment
./adk-mgmt.sh cleanup                # Clean up resources
```

### 🛠️ Troubleshooting
```bash
./adk-mgmt.sh fix oauth              # Fix OAuth redirect issues
./adk-mgmt.sh fix quota              # Help with quota issues
./adk-mgmt.sh debug                  # Debug deployment issues
```

## 🔄 Migration from Legacy Scripts

The individual scripts have been moved to `scripts/legacy/` and replaced with the unified system.

### Automatic Migration Helper

```bash
# If you try to run an old script name
./scripts/migrate.sh check-env-simple

# Shows the new equivalent command and offers to run it
```

### Command Mapping

| Legacy Script | New Unified Command |
|---------------|-------------------|
| `check-env-simple.sh` | `adk-mgmt.sh env check` |
| `deploy-secure.sh` | `adk-mgmt.sh deploy local` |
| `deploy-gke-production.sh` | `adk-mgmt.sh deploy production` |
| `test-dual-auth.sh` | `adk-mgmt.sh test auth` |
| `setup-domain.sh` | `adk-mgmt.sh domain setup` |
| `quick-deploy.sh` | `adk-mgmt.sh deploy quick` |

**See `scripts/migrate.sh` for the complete mapping.**

## 🎛️ Advanced Usage

### Command Options

```bash
# Use custom namespace
./adk-mgmt.sh deploy local -n my-namespace

# Use custom Helm release name
./adk-mgmt.sh deploy local -r my-release

# Use custom values file
./adk-mgmt.sh deploy local -f my-values.yaml

# Verbose output
./adk-mgmt.sh deploy local -v
```

### Combining Commands

```bash
# Full deployment workflow
./adk-mgmt.sh env check && \
./adk-mgmt.sh deploy local && \
./adk-mgmt.sh test all

# Quick troubleshooting
./adk-mgmt.sh status && \
./adk-mgmt.sh logs && \
./adk-mgmt.sh debug
```

## 🔄 Common Workflows

### 🆕 First-Time Setup
```bash
./adk-mgmt.sh env setup              # Interactive environment setup
./adk-mgmt.sh domain setup           # Configure domain (optional)
./adk-mgmt.sh deploy local           # Deploy application
./adk-mgmt.sh test all               # Verify everything works
```

### 🚀 Production Deployment
```bash
./adk-mgmt.sh env check              # Verify environment
./adk-mgmt.sh dns setup              # Configure DNS
./adk-mgmt.sh deploy production      # Production deployment
./adk-mgmt.sh test all               # Test production setup
```

### 🧪 Development Workflow
```bash
./adk-mgmt.sh deploy local           # Deploy changes
./adk-mgmt.sh test auth              # Test authentication
./adk-mgmt.sh logs                   # Check logs
./adk-mgmt.sh restart                # Restart if needed
```

### � Troubleshooting Workflow
```bash
./adk-mgmt.sh status                 # Check current status
./adk-mgmt.sh debug                  # Get debug information
./adk-mgmt.sh fix oauth              # Fix OAuth issues (if applicable)
./adk-mgmt.sh test connectivity      # Test network connectivity
```

## 📁 File Structure

```
scripts/
├── adk-mgmt.sh              # 🆕 Unified management script
├── common.sh                # Shared utility functions
├── migrate.sh               # Migration helper
├── README.md                # This documentation
├── QUICK-REFERENCE.md       # Quick command reference
├── INDEX.md                 # Documentation index
└── legacy/                  # Legacy individual scripts
    ├── check-env-simple.sh
    ├── deploy-secure.sh
    ├── setup-domain.sh
    └── ... (all old scripts)
```

## 🚨 Troubleshooting

### Common Issues

#### "Command not found"
```bash
# Make sure script is executable
chmod +x scripts/adk-mgmt.sh

# Use full path if needed
./scripts/adk-mgmt.sh env check
```

#### "Environment check failed"
```bash
# Run interactive setup
./adk-mgmt.sh env setup

# Or manually edit .env file
cp .env.example .env
# Edit .env with your values
```

#### "Deployment failed"
```bash
# Check status and debug
./adk-mgmt.sh status
./adk-mgmt.sh debug
./adk-mgmt.sh logs
```

#### "OAuth issues"
```bash
# Use built-in OAuth troubleshooting
./adk-mgmt.sh fix oauth
./adk-mgmt.sh test auth
```

### Getting Help

```bash
# Full help
./adk-mgmt.sh --help

# Quick reference
cat scripts/QUICK-REFERENCE.md

# Migration help
./scripts/migrate.sh
```

## 💡 Benefits of the Unified System

### ✅ **Simplified Interface**
- Single command entry point
- Consistent argument structure
- Intuitive command hierarchy

### ✅ **Reduced Duplication**
- Eliminated 21 individual scripts
- Shared common functions
- Consistent error handling

### ✅ **Better User Experience**
- Progressive disclosure of complexity
- Built-in help system
- Automatic prerequisite checking

### ✅ **Easier Maintenance**
- Single codebase to maintain
- Shared utility functions
- Centralized configuration

### ✅ **Enhanced Functionality**
- Advanced options and flags
- Better error messages
- Integrated troubleshooting

## 📝 Notes

- Legacy scripts remain available in `scripts/legacy/` for compatibility
- The unified script uses the same configuration files (`.env`, `terraform.tfvars`)
- All functionality from individual scripts has been preserved and enhanced
- Migration helper assists with transitioning to new commands

## 📖 Detailed Script Reference

### 🚀 Deployment Scripts

#### `deploy-secure.sh`
**Purpose**: Secure Helm deployment using environment variables from .env file
**Usage**: `./scripts/deploy-secure.sh`
**Prerequisites**: 
- `.env` file configured
- Kubernetes cluster accessible
- Helm installed

**What it does**:
- Loads environment variables from `.env` file
- Validates required variables
- Substitutes variables in Helm values file
- Deploys/upgrades the Helm chart
- Shows access information

**Example**:
```bash
./scripts/deploy-secure.sh
```

#### `deploy-gke-production.sh`
**Purpose**: Full production deployment to Google Kubernetes Engine
**Usage**: `./scripts/deploy-gke-production.sh`
**Prerequisites**: 
- GKE cluster running
- `.env` file configured
- Google Cloud authentication

**What it does**:
- Validates environment variables
- Creates production values file
- Deploys with production configuration
- Sets up ingress and DNS
- Configures TLS certificates

**Example**:
```bash
./scripts/deploy-gke-production.sh
```

#### `deploy-quota-limited.sh`
**Purpose**: Deploy with minimal resource requests for quota-limited environments
**Usage**: `./scripts/deploy-quota-limited.sh`
**Prerequisites**: 
- Limited CPU quota in GCP
- `.env` file configured

**What it does**:
- Uses quota-limited values file
- Reduces resource requests
- Deploys with minimal configuration
- Suitable for development/testing

**Example**:
```bash
./scripts/deploy-quota-limited.sh
```

#### `quick-deploy.sh`
**Purpose**: Interactive deployment with DNS setup options
**Usage**: `./scripts/quick-deploy.sh`
**Interactive**: Yes (provides menu options)

**What it does**:
- Presents deployment options menu
- Handles DNS setup automatically
- Deploys infrastructure and application
- Provides access URLs

**Example**:
```bash
./scripts/quick-deploy.sh
# Follow interactive prompts
```

### ⚙️ Setup & Configuration Scripts

#### `setup-domain.sh`
**Purpose**: Configure custom domain settings for Terraform deployment
**Usage**: `./scripts/setup-domain.sh`
**Interactive**: Yes

**What it does**:
- Creates/updates `terraform.tfvars`
- Configures domain and subdomain settings
- Sets up DNS zone options
- Validates domain configuration

**Example**:
```bash
./scripts/setup-domain.sh
# Follow prompts to configure your domain
```

#### `setup-dns.sh`
**Purpose**: Set up Google Cloud DNS for your domain
**Usage**: `./scripts/setup-dns.sh`
**Prerequisites**: 
- Domain ownership
- Google Cloud project configured

**What it does**:
- Creates Google Cloud DNS zone
- Configures name servers
- Sets up A records
- Integrates with Terraform

**Example**:
```bash
./scripts/setup-dns.sh
```

#### `setup-oauth.sh`
**Purpose**: Configure Google OAuth for OpenWebUI SSO
**Usage**: `./scripts/setup-oauth.sh`
**Interactive**: Yes

**What it does**:
- Guides OAuth 2.0 setup in Google Cloud Console
- Configures redirect URIs
- Updates Helm values for OAuth
- Tests OAuth configuration

**Example**:
```bash
./scripts/setup-oauth.sh
```

#### `setup-nip-io.sh`
**Purpose**: Quick setup using nip.io (no domain purchase required)
**Usage**: `./scripts/setup-nip-io.sh`
**Prerequisites**: 
- LoadBalancer IP available

**What it does**:
- Gets LoadBalancer IP from Terraform
- Configures nip.io domain
- Updates Terraform variables
- Deploys with automatic domain

**Example**:
```bash
./scripts/setup-nip-io.sh
```

### 🧪 Testing & Validation Scripts

#### `test-dns.sh`
**Purpose**: Validate DNS configuration and test domain resolution
**Usage**: `./scripts/test-dns.sh`
**Prerequisites**: 
- DNS configured
- Domain set up

**What it does**:
- Tests DNS resolution
- Validates A records
- Checks DNS propagation
- Verifies SSL certificates

**Example**:
```bash
./scripts/test-dns.sh
```

#### `test-domain-setup.sh`
**Purpose**: Validate domain configuration before deployment
**Usage**: `./scripts/test-domain-setup.sh`
**Prerequisites**: 
- `terraform.tfvars` configured

**What it does**:
- Validates Terraform variables
- Checks domain settings
- Tests DNS configuration
- Provides recommendations

**Example**:
```bash
./scripts/test-domain-setup.sh
```

#### `test-dual-auth.sh`
**Purpose**: Test dual authentication configuration
**Usage**: `./scripts/test-dual-auth.sh`
**Prerequisites**: 
- Application deployed
- OAuth configured

**What it does**:
- Tests Google OAuth login
- Tests password authentication
- Verifies dual auth setup
- Shows authentication options

**Example**:
```bash
./scripts/test-dual-auth.sh
```

#### `test-loadbalancer.sh`
**Purpose**: Test LoadBalancer connectivity
**Usage**: `./scripts/test-loadbalancer.sh`
**Prerequisites**: 
- Kubernetes cluster running
- LoadBalancer service deployed

**What it does**:
- Creates test OpenWebUI deployment
- Tests external connectivity
- Validates LoadBalancer configuration
- Provides access URLs

**Example**:
```bash
./scripts/test-loadbalancer.sh
```

#### `validate-terraform.sh`
**Purpose**: Validate Terraform configuration without applying changes
**Usage**: `./scripts/validate-terraform.sh`
**Prerequisites**: 
- Terraform installed
- `terraform.tfvars` configured

**What it does**:
- Initializes Terraform
- Validates syntax
- Checks formatting
- Runs terraform plan

**Example**:
```bash
./scripts/validate-terraform.sh
```

### 🔒 Environment & Security Scripts

#### `check-env.sh`
**Purpose**: Comprehensive environment variables verification
**Usage**: `./scripts/check-env.sh`
**Prerequisites**: 
- `.env` file exists

**What it does**:
- Validates all required environment variables
- Checks variable formats
- Provides detailed feedback
- Shows next steps

**Example**:
```bash
./scripts/check-env.sh
```

#### `check-env-simple.sh`
**Purpose**: Simple environment variables check
**Usage**: `./scripts/check-env-simple.sh`
**Prerequisites**: 
- `.env` file exists

**What it does**:
- Quick validation of key variables
- Shows environment status
- Provides deployment readiness check

**Example**:
```bash
./scripts/check-env-simple.sh
```

#### `security-check.sh`
**Purpose**: Security pre-commit check for sensitive information
**Usage**: `./scripts/security-check.sh`
**When to use**: Before committing code to Git

**What it does**:
- Scans for OAuth secrets in files
- Checks for exposed credentials
- Validates `.gitignore` rules
- Prevents accidental commits

**Example**:
```bash
./scripts/security-check.sh
```

### ✅ Verification Scripts

#### `verify-admin-password.sh`
**Purpose**: Verify admin password configuration
**Usage**: `./scripts/verify-admin-password.sh`
**Prerequisites**: 
- Application deployed
- Admin credentials configured

**What it does**:
- Tests admin login
- Verifies password authentication
- Checks admin privileges
- Validates configuration

**Example**:
```bash
./scripts/verify-admin-password.sh
```

#### `verify-auth-complete.sh`
**Purpose**: Complete authentication features verification
**Usage**: `./scripts/verify-auth-complete.sh`
**Prerequisites**: 
- Application deployed
- Authentication configured

**What it does**:
- Tests all authentication methods
- Verifies OAuth and password login
- Checks API endpoints
- Provides comprehensive auth status

**Example**:
```bash
./scripts/verify-auth-complete.sh
```

### 🛠️ Utility & Helper Scripts

#### `buy-domain.sh`
**Purpose**: Domain purchase helper using Google Cloud Domains
**Usage**: `./scripts/buy-domain.sh`
**Interactive**: Yes

**What it does**:
- Searches available domains
- Guides through purchase process
- Configures domain settings
- Integrates with deployment

**Example**:
```bash
./scripts/buy-domain.sh
```

#### `request-quota-increase.sh`
**Purpose**: GCP quota increase helper
**Usage**: `./scripts/request-quota-increase.sh`
**When to use**: When deployment fails due to quota limits

**What it does**:
- Shows current quota usage
- Provides quota increase guidance
- Generates support request templates
- Offers alternative solutions

**Example**:
```bash
./scripts/request-quota-increase.sh
```

#### `fix-oauth-redirect.sh`
**Purpose**: Fix OAuth redirect URI configuration issues
**Usage**: `./scripts/fix-oauth-redirect.sh`
**When to use**: When OAuth login fails with redirect errors

**What it does**:
- Identifies redirect URI mismatches
- Provides correct URIs for Google Console
- Tests OAuth configuration
- Guides through fixes

**Example**:
```bash
./scripts/fix-oauth-redirect.sh
```

## 🔄 Common Workflows

### First-Time Deployment

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your values

# 2. Verify setup
./scripts/check-env-simple.sh

# 3. Configure domain (choose one)
./scripts/setup-domain.sh      # Custom domain
./scripts/setup-nip-io.sh      # Quick testing

# 4. Deploy
./scripts/deploy-secure.sh

# 5. Verify
./scripts/verify-auth-complete.sh
```

### Production Deployment

```bash
# 1. Full environment check
./scripts/check-env.sh

# 2. Validate Terraform
./scripts/validate-terraform.sh

# 3. Set up DNS
./scripts/setup-dns.sh

# 4. Production deployment
./scripts/deploy-gke-production.sh

# 5. Test everything
./scripts/test-dns.sh
./scripts/verify-auth-complete.sh
```

### Troubleshooting Workflow

```bash
# 1. Check basic setup
./scripts/check-env-simple.sh

# 2. Test domain configuration
./scripts/test-domain-setup.sh

# 3. Verify DNS
./scripts/test-dns.sh

# 4. Check authentication
./scripts/test-dual-auth.sh

# 5. Fix specific issues
./scripts/fix-oauth-redirect.sh     # OAuth issues
./scripts/request-quota-increase.sh # Quota issues
```

### Development Workflow

```bash
# 1. Quick setup for testing
./scripts/setup-nip-io.sh

# 2. Deploy with limited resources
./scripts/deploy-quota-limited.sh

# 3. Test features
./scripts/test-loadbalancer.sh
./scripts/verify-auth-complete.sh
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### "Script not found" error
```bash
# Make sure you're in the project root
pwd
# Should show: .../Agentic Data Governance

# Make scripts executable
chmod +x scripts/*.sh
```

#### ".env file not found"
```bash
# Copy example file
cp .env.example .env
# Edit with your values
```

#### "Permission denied" error
```bash
# Make script executable
chmod +x scripts/script-name.sh
```

#### OAuth redirect URI mismatch
```bash
# Use the fix script
./scripts/fix-oauth-redirect.sh
```

#### DNS resolution issues
```bash
# Test DNS configuration
./scripts/test-dns.sh
```

#### Quota exceeded errors
```bash
# Get help with quota increase
./scripts/request-quota-increase.sh
```

### Getting Help

Each script provides helpful output and error messages. For additional help:

1. **Check Prerequisites**: Ensure all required tools are installed
2. **Verify Environment**: Run `./scripts/check-env-simple.sh`
3. **Read Error Messages**: Scripts provide detailed error information
4. **Use Test Scripts**: Run relevant test scripts to diagnose issues
5. **Check Documentation**: Refer to the main project documentation

### Running Scripts from Different Locations

**From Project Root** (Recommended):
```bash
./scripts/script-name.sh
```

**From Scripts Directory**:
```bash
cd scripts
./script-name.sh
```

**Using the Script Runner**:
```bash
./run-script.sh script-name
```

## 📝 Notes

- All scripts include comprehensive error checking and helpful output
- Scripts are designed to be run from the project root directory
- Environment variables should be configured in the `.env` file
- Some scripts require interactive input for configuration
- Scripts automatically handle file paths and dependencies
- Progress indicators and colored output make scripts easy to follow
