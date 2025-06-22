# Kubernetes/Helm Deployment Guide

This guide covers deploying the ADK application with OpenWebUI and the Ollama proxy to Google Kubernetes Engine (GKE) using Terraform and Helm.

## Architecture Overview

The deployed architecture consists of three main components running in a single pod:

1. **OpenWebUI Frontend** - Web interface for AI interactions
2. **Ollama Proxy** - Translation layer that converts OpenWebUI requests to ADK format
3. **ADK Backend** - Google Agent Development Kit backend service

```
Internet → Ingress → Service → Pod:
                                ├── OpenWebUI (port 8080)
                                ├── Ollama Proxy (port 11434)
                                └── ADK Backend (port 8000)
```

## Prerequisites

- Google Cloud Project with billing enabled
- GitHub repository with appropriate secrets configured
- Domain name for the application (optional for local testing)
- Docker images built and pushed to Google Artifact Registry

## Infrastructure Components

### Google Cloud Resources
- **GKE Autopilot Cluster** - Managed Kubernetes cluster
- **Artifact Registry** - Docker image repository
- **IAM Service Accounts** - For secure access
- **Workload Identity Federation** - Keyless authentication from GitHub Actions

### Kubernetes Resources
- **NGINX Ingress Controller** - Traffic routing and SSL termination
- **cert-manager** - Automatic SSL certificate management
- **Application Deployment** - Multi-container pod with all services

## Configuration Files

### Terraform Variables

The following variables must be configured in `terraform/terraform.tfvars`:

```hcl
gcp_project_id      = "your-gcp-project-id"
github_repo         = "your-username/your-repo"
app_host            = "your-domain.com"
oauth_client_id     = "your-oauth-client-id.apps.googleusercontent.com"
oauth_client_secret = "your-oauth-client-secret"
adk_image_tag       = "v1.0.0"        # Will be set by CI/CD
ollama_image_tag    = "v1.0.0"        # Will be set by CI/CD
```

### Helm Values

The Helm chart supports different configurations:

- **`values.yaml`** - Production configuration with templated variables
- **`values-local.yaml`** - Local development configuration

Key configuration sections:

```yaml
# Open WebUI Frontend
openWebUI:
  image:
    repository: ghcr.io/open-webui/open-webui
    tag: main
  sso:
    enabled: true  # Google OAuth integration

# ADK Backend
adkBackend:
  image:
    repository: "${adk_image_repository}"
    tag: "${adk_image_tag}"
  port: 8000

# Ollama Proxy
ollamaProxy:
  image:
    repository: "${ollama_image_repository}"
    tag: "${ollama_image_tag}"
  port: 11434
```

## Deployment Methods

### 1. Automated Deployment (Recommended)

The GitHub Actions workflow automatically deploys when changes are pushed to the main branch:

1. **Build Phase** - Builds and pushes Docker images to Artifact Registry
2. **Deploy Phase** - Runs Terraform to provision infrastructure and deploy application

Workflow file: `.github/workflows/deploy.yml`

### 2. Manual Deployment

For manual deployment or testing:

```bash
# 1. Authenticate with Google Cloud
gcloud auth application-default login

# 2. Configure Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# 3. Build and push images (if not using CI/CD)
cd adk-backend
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/adk-backend:${TAG} .
docker build -f Dockerfile.ollama-proxy -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/ollama-proxy:${TAG} .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/adk-backend:${TAG}
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/ollama-proxy:${TAG}

# 4. Deploy with Terraform
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Local Development Deployment

For local testing with Helm directly:

```bash
# Use local values
helm install webui-adk-local ./webui-adk-chart -f ./webui-adk-chart/values-local.yaml

# Or upgrade existing deployment
helm upgrade webui-adk-local ./webui-adk-chart -f ./webui-adk-chart/values-local.yaml
```

## Post-Deployment Configuration

### 1. DNS Configuration

After first deployment, configure DNS:

```bash
# Get the ingress IP address
terraform output ingress_ip

# Create A record: your-domain.com → <ingress-ip>
```

### 2. SSL Certificate

cert-manager automatically provisions SSL certificates via Let's Encrypt. Monitor the certificate status:

```bash
kubectl get certificates
kubectl describe certificate webui-tls-secret
```

### 3. Application Access

Once deployed, access the application at:
- **Production**: `https://your-domain.com`
- **Local**: `http://localhost:30080` (when using NodePort)

## Monitoring and Troubleshooting

### Check Deployment Status

```bash
# Check pods
kubectl get pods

# Check services
kubectl get services

# Check ingress
kubectl get ingress

# Check logs
kubectl logs -l app=webui-adk -c open-webui
kubectl logs -l app=webui-adk -c ollama-proxy
kubectl logs -l app=webui-adk -c adk-backend
```

### Common Issues

1. **Image Pull Errors**
   - Verify images exist in Artifact Registry
   - Check service account permissions

2. **SSL Certificate Issues**
   - Ensure DNS is properly configured
   - Check cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`

3. **OAuth/SSO Issues**
   - Verify Google OAuth credentials
   - Check redirect URLs in Google Cloud Console

4. **Inter-Container Communication**
   - All containers run in the same pod and can communicate via localhost
   - OpenWebUI connects to Ollama proxy on `http://localhost:11434`
   - Ollama proxy connects to ADK backend on `http://localhost:8000`

## Security Considerations

- **Service Accounts**: Uses workload identity for secure GCP access
- **Network Policies**: Consider implementing network policies for additional security
- **Secrets Management**: OAuth secrets stored as Kubernetes secrets
- **Image Security**: Use specific image tags in production, not `latest`

## Scaling and Performance

- **GKE Autopilot**: Automatically scales nodes based on demand
- **Pod Resources**: Configure resource requests/limits in Helm values
- **Horizontal Pod Autoscaler**: Can be added for automatic pod scaling

## Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy
```

This will remove:
- GKE cluster and all workloads
- Artifact Registry repository
- IAM service accounts and bindings
- All associated Google Cloud resources

## Support

For issues:
1. Check the pod logs first
2. Verify configuration in Helm values
3. Check Terraform state for infrastructure issues
4. Review GitHub Actions logs for CI/CD problems
