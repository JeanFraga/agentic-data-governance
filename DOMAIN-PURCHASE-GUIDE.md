# Domain Purchase Guide for OpenWebUI ADK Deployment

Since Google Cloud Domains might not be available in all regions, here are your options for getting a domain for your OpenWebUI ADK deployment.

## 🛒 Domain Purchase Options

### **Option 1: Popular Domain Registrars**

These are reliable, affordable registrars where you can purchase domains:

#### **Recommended Registrars:**

1. **Namecheap** (https://namecheap.com)
   - 💰 Affordable pricing (.com ~$9-13/year)
   - 🛡️ Free privacy protection
   - 🌐 Easy DNS management
   - ⭐ Excellent customer support

2. **Google Domains** (https://domains.google.com)
   - 🔧 Integrates well with Google Cloud
   - 💰 Transparent pricing (~$12/year for .com)
   - 🛡️ Built-in privacy protection
   - 📞 Good customer support

3. **Cloudflare Registrar** (https://www.cloudflare.com/registrar/)
   - 💰 At-cost pricing (no markup)
   - 🚀 Excellent performance
   - 🛡️ Free privacy protection
   - 🔒 Enhanced security features

4. **Porkbun** (https://porkbun.com)
   - 💰 Very competitive pricing
   - 🛡️ Free WHOIS privacy
   - 🎁 Often has promotions
   - 🌐 Good DNS management

### **Option 2: Use Your LoadBalancer IP (No Domain Required)**

You can skip domain purchase entirely and use the LoadBalancer IP directly:

```bash
# Your app is accessible at:
http://34.133.61.91

# For HTTPS, you can use services like:
# - nip.io: 34-133-61-91.nip.io
# - xip.io: 34.133.61.91.xip.io
```

#### **Update terraform.tfvars for IP-only access:**

```hcl
# Skip DNS entirely
domain_name = ""
create_dns_zone = false
app_host = "webui.example.com"  # Placeholder, will use IP
```

### **Option 3: Free Development Domains**

For development and testing:

#### **nip.io (Recommended for development)**
- Format: `34-133-61-91.nip.io`
- Automatically resolves to your IP
- No registration required
- Supports HTTPS with Let's Encrypt

#### **xip.io**
- Format: `34.133.61.91.xip.io`
- Similar to nip.io
- No registration required

#### **Update terraform.tfvars for nip.io:**

```hcl
# Use nip.io for development
domain_name = "34-133-61-91.nip.io"
create_dns_zone = false  # Don't create DNS zone
app_host = "app.34-133-61-91.nip.io"
```

## 📋 Suggested Domain Names

Based on your "Agentic Data Governance" project:

### **Professional (.com domains)**
- `agenticdata.com`
- `dataagent.com`
- `agentgov.com`
- `smartgov.com`
- `aigovernance.com`
- `datagovai.com`
- `intelligov.com`

### **Tech-focused (.ai, .io domains)**
- `agenticdata.ai`
- `dataagent.ai`
- `agentgov.io`
- `smartgov.ai`
- `govdata.ai`

### **Organization (.org domains)**
- `agenticdata.org`
- `aigovernance.org`
- `datagovernance.org`

## 🔧 Steps to Purchase and Configure

### **Step 1: Purchase Domain**

1. **Choose a registrar** from the list above
2. **Search for your desired domain**
3. **Complete the purchase** (usually $9-15/year for .com)
4. **Enable privacy protection** (usually free)

### **Step 2: Configure DNS**

After purchasing, you have two options:

#### **Option A: Use Google Cloud DNS (Recommended)**

1. **Keep the DNS zone** you already created
2. **Update your domain registrar** with these name servers:
   ```
   ns-cloud-b1.googledomains.com.
   ns-cloud-b2.googledomains.com.
   ns-cloud-b3.googledomains.com.
   ns-cloud-b4.googledomains.com.
   ```

3. **Update terraform.tfvars** with your new domain:
   ```hcl
   domain_name = "your-new-domain.com"
   app_host = "app.your-new-domain.com"
   ```

#### **Option B: Use Registrar's DNS**

1. **Set create_dns_zone = false** in terraform.tfvars
2. **Create A record** at your registrar:
   - Name: `app` (or `@` for root domain)
   - Type: `A`
   - Value: `34.133.61.91`

### **Step 3: Deploy with New Domain**

```bash
# Update DNS configuration
./setup-dns.sh

# Deploy with new domain
cd terraform
terraform apply
```

## 🧪 Testing Without Domain Purchase

If you want to test first before buying a domain:

### **1. Use nip.io (Easiest)**

```bash
# Update terraform.tfvars
domain_name = "34-133-61-91.nip.io"
create_dns_zone = false
app_host = "app.34-133-61-91.nip.io"

# Deploy
terraform apply
```

Your app will be accessible at: `https://app.34-133-61-91.nip.io`

### **2. Use Direct IP**

```bash
# Access directly via IP
http://34.133.61.91

# Or use port-forward for local testing
kubectl port-forward svc/webui-adk-openwebui 8080:80
# Then access: http://localhost:8080
```

## 💡 Recommendations

### **For Development/Testing:**
- Use **nip.io** or direct IP access
- Quick, free, and works immediately

### **For Production:**
- Buy a **.com domain** from **Namecheap** or **Google Domains**
- Use **Google Cloud DNS** for management
- Enable **DNSSEC** for security

### **Budget-Friendly:**
- **Porkbun** or **Namecheap** for affordable domains
- **.com** domains are most professional
- Look for first-year discounts

## 🚀 Quick Start Commands

### **Test with nip.io (no domain purchase):**
```bash
# Update terraform.tfvars with nip.io domain
echo 'domain_name = "34-133-61-91.nip.io"' >> terraform/terraform.tfvars
echo 'create_dns_zone = false' >> terraform/terraform.tfvars  
echo 'app_host = "app.34-133-61-91.nip.io"' >> terraform/terraform.tfvars

# Deploy
cd terraform && terraform apply
```

### **After buying a real domain:**
```bash
# Run the setup script
./setup-dns.sh

# Follow prompts to configure your new domain
# Deploy
cd terraform && terraform apply
```

The choice depends on your needs:
- **Development**: Use nip.io or direct IP
- **Demo/Presentation**: Buy a real domain (~$10-15)
- **Production**: Buy a professional domain with proper DNS setup
