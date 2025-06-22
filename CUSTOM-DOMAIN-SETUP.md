# 🌐 Custom Domain Setup Guide with Terraform

This guide will help you set up a professional custom domain for your AI application using Terraform, with automatic DNS management and TLS certificates.

## 📋 **Prerequisites**

1. **Domain Name**: You need to own a domain (e.g., `example.com`)
2. **DNS Control**: Ability to configure DNS at your domain registrar
3. **GCP Project**: With necessary permissions
4. **Terraform**: Configured and authenticated

## 🚀 **Setup Options**

### Option A: Automatic DNS Management (Recommended)

Let Terraform manage everything including DNS records:

```bash
# In terraform/terraform.tfvars
app_host            = "webui.example.com"
domain_name         = "example.com"
create_dns_zone     = true
enable_https        = true
tls_email           = "admin@example.com"
```

### Option B: External DNS Management

Manage DNS yourself, let Terraform handle applications:

```bash
# In terraform/terraform.tfvars
app_host            = "webui.example.com"
create_dns_zone     = false
enable_https        = true
tls_email           = "admin@example.com"
```

## 📝 **Step-by-Step Setup**

### 1. Configure Terraform Variables

Update your `terraform/terraform.tfvars`:

```hcl
# Basic Configuration
gcp_project_id      = "your-actual-project-id"
github_repo         = "your-github-username/your-repo-name"
app_host            = "webui.yourdomain.com"
oauth_client_id     = "your-oauth-client-id"
oauth_client_secret = "your-oauth-client-secret"
admin_password      = "your-secure-password"

# Domain Configuration
domain_name         = "yourdomain.com"        # Your root domain
create_dns_zone     = true                    # Let Terraform manage DNS
enable_https        = true                    # Enable HTTPS certificates
tls_email           = "admin@yourdomain.com"  # For Let's Encrypt

# Deployment Settings
deploy_kubernetes_resources = true
```

### 2. Deploy with Terraform

```bash
cd terraform

# Initialize and plan
terraform init
terraform plan

# Deploy infrastructure and application
terraform apply
```

### 3. Configure DNS (If using Option A)

After deployment, Terraform will output the Google Cloud DNS name servers:

```bash
# Get the name servers
terraform output dns_zone_name_servers
```

Configure these name servers at your domain registrar:
- Go to your domain registrar's DNS settings
- Replace existing name servers with the Google Cloud ones
- Wait for DNS propagation (5-60 minutes)

### 4. Verify Setup

```bash
# Check Terraform outputs
terraform output app_url
terraform output ingress_ip

# Test DNS resolution
nslookup webui.yourdomain.com

# Test HTTPS certificate
curl -I https://webui.yourdomain.com
```

## 🛠️ **Configuration Details**

### DNS Zone Management

When `create_dns_zone = true`, Terraform will:
- Create a Google Cloud DNS zone for your domain
- Automatically create A records pointing to the load balancer
- Manage DNS records declaratively

### TLS Certificate Management

When `enable_https = true`, the system will:
- Use cert-manager to request Let's Encrypt certificates
- Automatically renew certificates before expiration
- Configure NGINX ingress for HTTPS redirection

### Ingress Configuration

The ingress will be configured with:
- Custom domain routing
- Automatic TLS termination
- Large file upload support for AI workloads
- Extended timeouts for long-running requests

## 🔧 **Advanced Configuration**

### Custom Domain with Subdomain

```hcl
app_host     = "ai.company.com"
domain_name  = "company.com"
```

### Multiple Subdomains (Future Extension)

```hcl
# Can be extended to support multiple apps
app_host     = "webui.company.com"
api_host     = "api.company.com"
docs_host    = "docs.company.com"
```

### Production Hardening

```hcl
# Additional security headers
ingress_annotations = {
  "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
  "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
  "nginx.ingress.kubernetes.io/custom-headers" = "security-headers"
}
```

## 🎯 **Access Your Application**

Once setup is complete, access your application at:

- **HTTPS**: `https://webui.yourdomain.com`
- **Automatic redirects**: HTTP → HTTPS
- **Valid certificate**: No browser warnings

## 🚨 **Troubleshooting**

### DNS Not Resolving

```bash
# Check DNS propagation
dig webui.yourdomain.com
dig @8.8.8.8 webui.yourdomain.com

# Check Google Cloud DNS
gcloud dns record-sets list --zone=your-dns-zone
```

### Certificate Issues

```bash
# Check cert-manager status
kubectl get certificates -A
kubectl describe certificate webui-yourdomain-com-tls-secret

# Check Let's Encrypt challenges
kubectl get challenges -A
```

### Ingress Issues

```bash
# Check ingress status
kubectl get ingress -A
kubectl describe ingress webui-adk-ingress

# Check NGINX controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## 🔄 **Updating Domain Configuration**

To change domains or DNS settings:

1. Update `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes
4. Update DNS at registrar if needed

## 💰 **Cost Considerations**

- **Google Cloud DNS**: ~$0.50/month per zone + queries
- **Load Balancer**: ~$18/month for regional LB
- **TLS Certificates**: Free via Let's Encrypt
- **GKE Autopilot**: Based on resource usage

## 📚 **Next Steps**

1. **Monitor**: Set up monitoring for domain and certificates
2. **Backup**: Configure backup strategies for DNS records
3. **Scale**: Plan for multiple environments (staging, prod)
4. **Security**: Implement additional security headers and policies

## 🎉 **Professional Benefits**

With custom domain setup:
- ✅ Professional appearance (`webui.company.com`)
- ✅ HTTPS security with valid certificates
- ✅ Automatic certificate renewal
- ✅ Infrastructure as Code management
- ✅ Scalable for multiple environments
