# GKE Website Access Guide

## Current Status
- ✅ Infrastructure: GKE cluster, NGINX Ingress Controller deployed
- ✅ Load Balancer: External IP available (34.133.61.91)
- ❌ Application: Not deployed due to CPU quota limit
- ❌ DNS/TLS: Pending application deployment

## Access Methods (Once Application is Deployed)

### 1. 🚀 **Via Load Balancer IP (Immediate Access)**
```bash
# Direct access via external IP
curl http://34.133.61.91
# or open in browser:
open http://34.133.61.91
```
**Pros**: Immediate access, no DNS setup needed
**Cons**: Uses IP address, no TLS certificate

### 2. 🌍 **Via Custom Domain (Production Setup)**
```bash
# After DNS setup:
curl https://your-domain.com
# or open in browser:
open https://your-domain.com
```
**Requirements**:
- DNS A record: `your-domain.com` → `34.133.61.91`
- TLS certificate (automatic via cert-manager)
**Pros**: Professional domain, HTTPS, automatic certificates

### 3. 🔧 **Via kubectl Port-Forward (Development)**
```bash
# Forward local port to service
kubectl port-forward -n webui-adk service/webui-adk-local 8080:80
# Access via:
open http://localhost:8080
```
**Pros**: Secure tunnel, works without external exposure
**Cons**: Requires kubectl access, temporary

### 4. 📡 **Via NodePort (Direct Node Access)**
```bash
# Get node external IP
kubectl get nodes -o wide
# Access via: http://NODE_IP:NODEPORT
# (NodePort will be in your values file)
```

## Current Available Access

### NGINX Ingress Controller
- **External IP**: `34.133.61.91`
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Status**: Ready and waiting for application

```bash
# Test ingress controller
curl -v http://34.133.61.91
# Should return 404 (no routes configured yet)
```

### Test Infrastructure
```bash
# Check ingress controller health
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## Next Steps to Enable Access

### Option A: Deploy with Quota Limits (Recommended)
```bash
# Deploy application with resource constraints
./deploy-quota-limited.sh

# Then access via:
open http://34.133.61.91
```

### Option B: Complete Terraform Deployment
```bash
# Enable full Kubernetes deployment in Terraform
cd terraform
terraform apply -var="deploy_kubernetes_resources=true"

# Access will be available at your configured domain
```

### Option C: Manual Helm Deployment
```bash
# Deploy directly with Helm
./deploy-secure.sh

# Access via load balancer IP or configured domain
```

## Configure Custom Domain (Optional)

1. **Purchase/Configure Domain**
   - Get a domain (e.g., from Google Domains, Cloudflare)

2. **Set DNS A Record**
   ```
   Type: A
   Name: @ (or www)
   Value: 34.133.61.91
   TTL: 300
   ```

3. **Update Helm Values**
   ```yaml
   # In values.yaml or terraform variables
   app_host: "your-domain.com"
   ```

4. **Redeploy**
   ```bash
   # Application will automatically get TLS certificate
   ./deploy-secure.sh
   ```

## Troubleshooting Access

### Check Application Status
```bash
# Pods
kubectl get pods -n webui-adk

# Services
kubectl get services -n webui-adk

# Ingress
kubectl get ingress -n webui-adk

# Logs
kubectl logs -n webui-adk -l app=webui-adk-local -f
```

### Check Load Balancer
```bash
# Service status
kubectl get service -n ingress-nginx ingress-nginx-controller

# Controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Test Connectivity
```bash
# From outside cluster
curl -v http://34.133.61.91

# DNS resolution (if using domain)
nslookup your-domain.com

# Certificate status (if using HTTPS)
curl -vI https://your-domain.com
```

## Security Considerations

- 🔒 **HTTPS**: Always use HTTPS in production
- 🛡️ **Firewall**: Consider GCP firewall rules
- 🔐 **Authentication**: OAuth/OIDC configured
- 📝 **Monitoring**: Enable logging and monitoring

## Current Load Balancer IP
**External IP**: `34.133.61.91`

This IP is ready to serve traffic once the application is deployed!
