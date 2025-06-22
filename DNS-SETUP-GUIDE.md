# DNS Setup Guide for OpenWebUI ADK Deployment

This guide explains how to set up DNS for your OpenWebUI ADK deployment using Google Cloud DNS and Terraform.

## Overview

The deployment supports three DNS configurations:

1. **Custom Domain with Google Cloud DNS** - Full DNS management with your own domain
2. **Existing DNS Zone** - Use an existing Google Cloud DNS zone
3. **LoadBalancer IP Only** - Skip DNS and use the LoadBalancer IP directly

## Prerequisites

- Google Cloud Project with billing enabled
- Domain name (if using custom domain)
- `gcloud` CLI authenticated and configured
- `terraform` installed
- `kubectl` configured for your GKE cluster

## DNS Setup Options

### Option 1: Automated DNS Setup (Recommended)

Use the interactive setup script:

```bash
./setup-dns.sh
```

This script will:
- Check if DNS API is enabled
- Help you choose between creating a new zone or using existing
- Configure terraform.tfvars with your domain settings
- Show you the name servers to configure at your registrar
- Validate the Terraform configuration

### Option 2: Manual DNS Setup

#### Step 1: Enable DNS API

```bash
gcloud services enable dns.googleapis.com
```

#### Step 2: Create DNS Zone (if needed)

```bash
# Replace with your domain and zone name
DOMAIN_NAME="example.com"
ZONE_NAME="my-app-dns-zone"

gcloud dns managed-zones create "$ZONE_NAME" \
    --description="DNS zone for $DOMAIN_NAME" \
    --dns-name="$DOMAIN_NAME." \
    --dnssec-state=on
```

#### Step 3: Get Name Servers

```bash
gcloud dns managed-zones describe "$ZONE_NAME" \
    --format="value(nameServers[].join('\n'))"
```

#### Step 4: Update terraform.tfvars

Add these variables to your `terraform/terraform.tfvars`:

```hcl
# DNS Configuration
domain_name = "example.com"
create_dns_zone = true  # or false if using existing zone
dns_zone_name = "my-app-dns-zone"
app_host = "example.com"  # or subdomain.example.com
```

### Option 3: Skip DNS Setup

Set in `terraform/terraform.tfvars`:

```hcl
domain_name = ""
create_dns_zone = false
app_host = "webui.example.com"  # Use default placeholder
```

## DNS Configuration Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `domain_name` | Your root domain | `""` | `"example.com"` |
| `create_dns_zone` | Create new DNS zone | `false` | `true` |
| `dns_zone_name` | Name for DNS zone | `"webui-dns-zone"` | `"my-app-zone"` |
| `app_host` | Full hostname for app | `"webui.example.com"` | `"app.example.com"` |
| `enable_https` | Enable TLS certificates | `true` | `true` |
| `tls_email` | Email for Let's Encrypt | `""` | `"admin@example.com"` |

## Domain Registrar Configuration

After creating the DNS zone, configure these name servers at your domain registrar:

1. Log into your domain registrar (GoDaddy, Namecheap, etc.)
2. Find DNS or name server settings
3. Replace existing name servers with Google Cloud DNS name servers
4. Save changes

**Example name servers:**
```
ns-cloud-a1.googledomains.com.
ns-cloud-a2.googledomains.com.
ns-cloud-a3.googledomains.com.
ns-cloud-a4.googledomains.com.
```

## DNS Records Created by Terraform

The Terraform configuration automatically creates:

1. **A Record**: Points your domain to the LoadBalancer IP
   - `example.com` → `34.102.136.180`

2. **CNAME Record** (optional): Points www to root domain
   - `www.example.com` → `example.com`

## Deployment Process

1. **Setup DNS** (choose one):
   ```bash
   ./setup-dns.sh              # Interactive setup
   # OR manually configure terraform.tfvars
   ```

2. **Deploy Infrastructure**:
   ```bash
   cd terraform
   terraform plan               # Review changes
   terraform apply              # Deploy everything
   ```

3. **Verify DNS**:
   ```bash
   ./test-dns.sh               # Test DNS resolution
   ```

4. **Access Application**:
   ```bash
   # Get your app URL
   terraform output app_url
   ```

## DNS Validation and Testing

### Using the Test Script

```bash
./test-dns.sh
```

This script checks:
- DNS zone configuration
- Name server setup
- Domain resolution
- HTTPS certificate status

### Manual DNS Testing

```bash
# Test domain resolution
dig your-domain.com
nslookup your-domain.com

# Test specific record types
dig your-domain.com A
dig your-domain.com CNAME

# Test from different DNS servers
dig @8.8.8.8 your-domain.com
dig @1.1.1.1 your-domain.com
```

### Check Ingress Status

```bash
# Get LoadBalancer IP
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Check ingress configuration
kubectl get ingress -A

# View certificate status
kubectl get certificate -A
kubectl describe certificate webui-adk-tls
```

## Troubleshooting

### DNS Zone Issues

**Problem**: Zone creation fails
```bash
# Check if zone already exists
gcloud dns managed-zones list

# Check quota limits
gcloud compute project-info describe --format="value(quotas[].limit,quotas[].metric)"
```

**Problem**: Permission denied
```bash
# Check DNS API is enabled
gcloud services list --enabled --filter="name:dns.googleapis.com"

# Check IAM permissions
gcloud projects get-iam-policy $(gcloud config get-value project)
```

### Domain Resolution Issues

**Problem**: Domain doesn't resolve
1. Verify name servers are configured at registrar
2. Check DNS propagation (can take up to 48 hours)
3. Test with different DNS servers

**Problem**: Wrong IP returned
1. Check DNS records in Google Cloud Console
2. Verify LoadBalancer IP is correct
3. Clear DNS cache: `sudo dscacheutil -flushcache`

### Certificate Issues

**Problem**: HTTPS not working
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl describe certificate webui-adk-tls

# Check ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod
```

**Problem**: Certificate pending
1. Verify domain resolves to correct IP
2. Check that port 80 is accessible
3. Review cert-manager and ingress logs

## DNS Propagation

DNS changes can take time to propagate:

- **Local DNS cache**: 5-30 minutes
- **ISP DNS servers**: 1-4 hours  
- **Global propagation**: Up to 48 hours

Test propagation:
```bash
# Online tools
# https://dnschecker.org/
# https://www.whatsmydns.net/

# Command line from different locations
dig @8.8.8.8 your-domain.com        # Google DNS
dig @1.1.1.1 your-domain.com        # Cloudflare DNS
dig @208.67.222.222 your-domain.com # OpenDNS
```

## Best Practices

1. **Use DNSSEC**: Enabled by default for security
2. **Monitor Certificate Expiry**: Let's Encrypt auto-renews
3. **Test from Multiple Locations**: DNS may vary by location
4. **Keep TTL Reasonable**: 300 seconds (5 minutes) for A records
5. **Plan for Changes**: Lower TTL before making changes

## Integration with Terraform

The DNS setup integrates seamlessly with Terraform:

```hcl
# Terraform manages these resources:
resource "google_dns_managed_zone" "domain_zone"     # DNS zone
resource "google_dns_record_set" "app_a_record"     # A record  
resource "google_dns_record_set" "www_cname_record" # CNAME record
```

### Terraform DNS Workflow

1. **Infrastructure First**: Deploy without Kubernetes resources
   ```bash
   terraform apply -var="deploy_kubernetes_resources=false"
   ```

2. **Configure DNS**: Set up domain and DNS zone
   ```bash
   ./setup-dns.sh
   ```

3. **Full Deployment**: Deploy everything including DNS records
   ```bash
   terraform apply -var="deploy_kubernetes_resources=true"
   ```

## Additional Resources

- [Google Cloud DNS Documentation](https://cloud.google.com/dns/docs)
- [Kubernetes Ingress Guide](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

## Support

If you encounter issues:

1. Run `./test-dns.sh` for diagnostics
2. Check the troubleshooting section above
3. Review Terraform and kubectl logs
4. Verify all prerequisites are met
