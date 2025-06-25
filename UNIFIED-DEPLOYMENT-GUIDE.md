# Unified Deployment Guide

This guide covers the unified deployment workflow for the Agentic Data Governance application using the consolidated Terraform configuration and management script.

## Overview

The application now supports both **local** (Docker Desktop) and **production** (GCP/GKE) deployments using a single Terraform codebase with environment-aware logic. This ensures consistency, reduces duplication, and provides safe isolation between environments.

## Key Features

- ✅ **Unified Terraform Configuration**: Single codebase for both environments
- ✅ **Environment Isolation**: Separate state files and backends
- ✅ **Safe Local Testing**: No risk of affecting production resources
- ✅ **Consolidated Management**: Single script for all operations
- ✅ **Dry-Run Support**: Preview changes before applying
- ✅ **Automatic Backend Switching**: Environment-appropriate state management

## Prerequisites

### For Local Deployment
- Docker Desktop with Kubernetes enabled
- Helm 3.x
- kubectl
- Terraform >= 1.0

### For Production Deployment
- Google Cloud SDK (gcloud)
- GCP Project with billing enabled
- Appropriate GCP permissions
- Helm 3.x
- kubectl
- Terraform >= 1.0

## Management Script

The unified management script `scripts/adk-mgmt.sh` is your single entry point for all deployment operations.

### Basic Usage

```bash
# Show help and available commands
./scripts/adk-mgmt.sh -h

# Check environment setup
./scripts/adk-mgmt.sh env check

# Deploy to local environment
./scripts/adk-mgmt.sh deploy local

# Deploy to production (with confirmation)
./scripts/adk-mgmt.sh deploy production

# Check deployment status
./scripts/adk-mgmt.sh status

# Destroy local deployment
./scripts/adk-mgmt.sh destroy local

# Destroy production deployment (requires double confirmation)
./scripts/adk-mgmt.sh destroy production
```

### Dry-Run Mode

Preview changes without applying them:

```bash
# Preview local deployment
./scripts/adk-mgmt.sh deploy local --dry-run

# Preview production deployment
./scripts/adk-mgmt.sh deploy production --dry-run

# Preview local destruction
./scripts/adk-mgmt.sh destroy local --dry-run
```

## Environment Configuration

### Local Environment

Local deployments use:
- **Backend**: Local state file (`terraform-local.tfstate`)
- **Config**: `terraform/terraform.tfvars.local`
- **Target**: Docker Desktop Kubernetes
- **Isolation**: Completely separate from production

### Production Environment

Production deployments use:
- **Backend**: GCS bucket (configured in `backend-production.tf.template`)
- **Config**: `terraform/terraform.tfvars` or `terraform/terraform.tfvars.production`
- **Target**: GKE cluster on GCP
- **Isolation**: Separate state and resources

## Terraform Configuration Files

### Core Files
- `terraform/main.tf` - Main infrastructure configuration (environment-aware)
- `terraform/variables.tf` - All variable definitions
- `terraform/outputs.tf` - Environment-aware outputs

### Environment-Specific Files
- `terraform/terraform.tfvars.local` - Local development configuration
- `terraform/terraform.tfvars` - Production configuration
- `terraform/terraform.tfvars.production` - Production template

### Backend Configuration
- `terraform/backend-local.tf.template` - Local backend template
- `terraform/backend-production.tf.template` - Production backend template
- `terraform/backend.tf` - Active backend (managed by script)

## Step-by-Step Deployment

### Local Development Deployment

1. **Ensure Docker Desktop is running** with Kubernetes enabled:
   ```bash
   kubectl config use-context docker-desktop
   ```

2. **Configure local environment**:
   ```bash
   ./scripts/adk-mgmt.sh env setup
   ```

3. **Deploy locally**:
   ```bash
   # Preview first (recommended)
   ./scripts/adk-mgmt.sh deploy local --dry-run
   
   # Deploy
   ./scripts/adk-mgmt.sh deploy local
   ```

4. **Check status**:
   ```bash
   ./scripts/adk-mgmt.sh status
   ```

5. **Access the application**:
   - The script will show you the local URLs after deployment
   - Typically: `http://localhost:30080` or similar

### Production Deployment

1. **Set up GCP credentials**:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Configure production environment**:
   - Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
   - Fill in your production values

3. **Preview deployment**:
   ```bash
   ./scripts/adk-mgmt.sh deploy production --dry-run
   ```

4. **Deploy to production**:
   ```bash
   ./scripts/adk-mgmt.sh deploy production
   ```

5. **Configure DNS** (if using custom domain):
   - Get the ingress IP from the deployment output
   - Update your DNS records

## Environment Variables

### Local Environment (`terraform.tfvars.local`)
```hcl
environment = "local"
namespace = "adk-local"
release_name = "adk-local"

# Local-specific settings
create_gke_cluster = false
create_dns_zone = false
domain_name = ""
```

### Production Environment (`terraform.tfvars`)
```hcl
environment = "production"
gcp_project_id = "your-project-id"
gcp_region = "us-central1"
cluster_name = "adk-cluster"
domain_name = "your-domain.com"

# Production settings
create_gke_cluster = true
create_dns_zone = true
enable_ingress = true
```

## Backend State Management

The script automatically manages Terraform backends to ensure proper state isolation:

- **Local**: Uses local state file (`terraform-local.tfstate`)
- **Production**: Uses GCS backend (configured in your backend template)

The script copies the appropriate backend template to `backend.tf` before running Terraform commands.

## Safety Features

### Confirmation Prompts
- Production deployments require explicit confirmation
- Production destruction requires typing "destroy-production"
- Dry-run mode shows what would happen without executing

### State Isolation
- Local and production use completely separate state files
- No risk of local operations affecting production resources
- Backend switching is automatic and safe

### Resource Scoping
- Environment variable controls which resources are created
- Local deployments don't create GCP resources
- Production deployments don't interfere with local resources

## Troubleshooting

### Common Issues

1. **Wrong Kubernetes context**:
   ```bash
   kubectl config current-context
   kubectl config use-context docker-desktop  # for local
   kubectl config use-context gke_PROJECT_cluster  # for production
   ```

2. **Backend initialization fails**:
   ```bash
   cd terraform
   rm -rf .terraform
   terraform init -reconfigure
   ```

3. **State file conflicts**:
   - Local and production use separate state files
   - Check that the correct backend is being used

### Debug Mode

For verbose output:
```bash
./scripts/adk-mgmt.sh deploy local --verbose
```

### Manual Terraform Operations

If you need to run Terraform manually:

```bash
cd terraform

# For local
cp backend-local.tf.template backend.tf
terraform init -reconfigure
terraform plan -var-file="terraform.tfvars.local"

# For production  
cp backend-production.tf.template backend.tf
terraform init -reconfigure
terraform plan -var-file="terraform.tfvars"
```

## Migration from Legacy Setup

If you're migrating from the old separate terraform-local directory:

1. **Backup existing state** (done automatically when using the script)
2. **Use the new unified workflow** as described above
3. **The old terraform-local directory** has been moved to `terraform-local-backup-*`

## Best Practices

1. **Always use dry-run first** for production changes
2. **Keep your tfvars files secure** and don't commit secrets
3. **Use the management script** instead of raw Terraform commands
4. **Test locally before deploying to production**
5. **Monitor your GCP costs** when using production environment

## Next Steps

- Set up monitoring and alerting
- Configure custom domains and SSL certificates  
- Implement CI/CD pipelines
- Set up backup and disaster recovery procedures

For more advanced configuration, see:
- [KUBERNETES-DEPLOYMENT.md](./KUBERNETES-DEPLOYMENT.md)
- [CUSTOM-DOMAIN-SETUP.md](./CUSTOM-DOMAIN-SETUP.md)
- [SECURE-CONFIG.md](./SECURE-CONFIG.md)
