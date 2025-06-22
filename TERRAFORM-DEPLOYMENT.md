# Two-Phase Terraform Deployment Guide

## Overview

The Terraform configuration has been updated to support a two-phase deployment approach to avoid dependency issues when creating the infrastructure and Kubernetes resources.

## Phase 1: Infrastructure Deployment

### Purpose
Create the core Google Cloud infrastructure:
- GKE Autopilot cluster
- Artifact Registry repository
- IAM service accounts and roles
- Workload Identity Federation

### Configuration
Set `deploy_kubernetes_resources = false` in `terraform.tfvars`:

```hcl
# terraform/terraform.tfvars
gcp_project_id      = "your-gcp-project-id"
github_repo         = "your-github-username/your-repo-name"
app_host            = "webui.your-domain.com"
oauth_client_id     = "your-google-client-id.apps.googleusercontent.com"
oauth_client_secret = "your-google-client-secret"
adk_image_tag       = "latest"

# Phase 1: Infrastructure only
deploy_kubernetes_resources = false
```

### Commands
```bash
cd terraform
terraform init
terraform plan   # ✅ Should show 10 resources to create
terraform apply  # Create infrastructure
```

### Expected Resources (10)
- `google_container_cluster.primary`
- `google_artifact_registry_repository.adk_repo`
- `google_service_account.github_actions_sa`
- `google_iam_workload_identity_pool.github_pool`
- `google_iam_workload_identity_pool_provider.github_provider`
- `google_project_iam_member.artifact_writer`
- `google_project_iam_member.gke_developer`
- `google_service_account_iam_member.wif_binding`
- `google_project_service.gke_api`
- `google_project_service.artifact_registry_api`

## Phase 2: Kubernetes Applications Deployment

### Purpose
Deploy the application components to the GKE cluster:
- NGINX Ingress Controller
- Cert Manager (for TLS certificates)
- LetsEncrypt ClusterIssuer
- WebUI-ADK application

### Configuration
After Phase 1 completes successfully, update `terraform.tfvars`:

```hcl
# Phase 2: Enable Kubernetes resources
deploy_kubernetes_resources = true
```

### Commands
```bash
# Get cluster credentials first
gcloud container clusters get-credentials webui-adk-cluster --region us-central1

# Deploy Kubernetes resources
terraform plan   # Should show additional Helm releases and K8s manifests
terraform apply  # Deploy applications
```

### Expected Additional Resources
- `helm_release.ingress_nginx[0]`
- `helm_release.cert_manager[0]`
- `kubernetes_manifest.letsencrypt_issuer[0]`
- `helm_release.webui_adk_app[0]`
- `data.kubernetes_service.ingress_nginx_controller[0]`

## Production vs Development

### For Production (via GitHub Actions)
```hcl
# terraform.tfvars
deploy_kubernetes_resources = true  # Deploy everything in one shot
```

### For Local Development/Testing
```hcl
# terraform.tfvars
deploy_kubernetes_resources = false  # Start with infrastructure only
```

## Benefits of Two-Phase Approach

1. **🛡️ Safer Deployments**: Infrastructure and applications deployed separately
2. **🔍 Better Debugging**: Easier to isolate issues between phases
3. **🎯 Flexible Testing**: Can test infrastructure without applications
4. **📊 Clear Dependencies**: No chicken-and-egg problems with Kubernetes providers

## Outputs by Phase

### Phase 1 Outputs
```
adk_image_uri                = "us-central1-docker.pkg.dev/your-gcp-project-id/webui-adk-repo/adk-backend:latest"
artifact_registry_repository = "projects/your-gcp-project-id/locations/us-central1/repositories/webui-adk-repo"
gke_cluster_name             = "webui-adk-cluster"
ingress_ip                   = "Kubernetes resources not deployed"
ollama_image_uri             = "us-central1-docker.pkg.dev/your-gcp-project-id/webui-adk-repo/ollama-proxy:latest"
```

### Phase 2 Outputs
```
ingress_ip = "34.102.136.180"  # Actual LoadBalancer IP
```

## Rollback Strategy

### Roll Back to Infrastructure Only
```bash
# In terraform.tfvars, set:
deploy_kubernetes_resources = false

terraform apply  # This will destroy Kubernetes resources but keep infrastructure
```

### Complete Rollback
```bash
terraform destroy  # Destroys everything
```

## Troubleshooting

### Common Issues

**Issue**: "no client config" errors during plan
**Solution**: Ensure `deploy_kubernetes_resources = false` for initial deployment

**Issue**: Helm releases fail to deploy
**Solution**: Verify cluster credentials: `gcloud container clusters get-credentials webui-adk-cluster --region us-central1`

**Issue**: DNS/TLS certificate issues
**Solution**: Ensure your domain's A record points to the ingress IP from outputs

### Validation Commands

```bash
# Check infrastructure
gcloud container clusters list
gcloud artifacts repositories list

# Check Kubernetes resources (Phase 2)
kubectl get nodes
kubectl get pods -n ingress-nginx
kubectl get pods -n cert-manager
kubectl get svc -n ingress-nginx
```

## Next Steps

1. ✅ Phase 1 complete: Infrastructure deployed
2. 🔄 Build and push Docker images to Artifact Registry
3. 🚀 Phase 2: Deploy applications
4. 🌐 Configure DNS and test application
5. 🔐 Set up production OAuth credentials
