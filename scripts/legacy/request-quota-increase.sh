#!/bin/bash

# Script to help request GCP quota increase
# This script provides guidance and helpful commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 GCP CPU Quota Increase Helper${NC}"
echo ""

# Check current quota usage
echo -e "${GREEN}📊 Current CPU Quota Status in us-central1:${NC}"
gcloud compute regions describe us-central1 --format="table(quotas.metric,quotas.usage,quotas.limit)" | grep CPUS || echo "No CPUS quota found"

echo ""
echo -e "${GREEN}📊 All CPU-related Quotas:${NC}"
gcloud compute regions describe us-central1 --format="yaml(quotas)" | grep -A 2 "CPUS"

echo ""
echo -e "${YELLOW}⚠️  Current Issue:${NC}"
echo "• Current quota: 24 CPUs"
echo "• Current usage: 16 CPUs (from existing node)"
echo "• Need: Additional CPUs for scaling"
echo "• Recommended new quota: 64-96 CPUs"

echo ""
echo -e "${BLUE}🔗 How to Request Quota Increase:${NC}"
echo ""
echo "1. 🌐 Open GCP Console Quotas Page:"
echo "   https://console.cloud.google.com/iam-admin/quotas?project=$(gcloud config get-value project)"
echo ""
echo "2. 🔍 Filter for CPU quotas:"
echo "   • Service: 'Compute Engine API'"
echo "   • Region: 'us-central1'"
echo "   • Metric: 'CPUs'"
echo ""
echo "3. ✏️  Edit quota:"
echo "   • Select the 'CPUs' quota for us-central1"
echo "   • Click 'EDIT QUOTAS'"
echo "   • Change limit from 24 to 64 (or 96 for future growth)"
echo ""
echo "4. 📝 Justification (copy/paste this):"
echo "   'Running production AI application (OpenWebUI + Ollama Proxy + ADK Backend) on GKE Autopilot."
echo "   Current deployment requires scaling beyond 24 CPU limit for optimal performance."
echo "   Application serves as an AI-powered data governance platform requiring compute resources"
echo "   for ML model inference and data processing workloads.'"
echo ""
echo "5. ⏳ Wait for approval (usually 24-48 hours)"

echo ""
echo -e "${GREEN}🔧 Alternative Solutions (if quota increase takes time):${NC}"
echo ""
echo "• 🚀 Use quota-limited deployment:"
echo "  ./deploy-quota-limited.sh"
echo ""
echo "• 🌍 Switch to different region with higher quota:"
echo "  Check: gcloud compute regions list"
echo ""
echo "• ⚡ Use smaller machine types:"
echo "  Current: ek-standard-16 (16 CPUs)"
echo "  Consider: ek-standard-8 (8 CPUs) or ek-standard-4 (4 CPUs)"

echo ""
echo -e "${BLUE}📈 Monitor quota usage:${NC}"
echo "watch 'gcloud compute regions describe us-central1 --format=\"table(quotas.metric,quotas.usage,quotas.limit)\" | grep CPUS'"

echo ""
echo -e "${GREEN}✅ Once quota is increased:${NC}"
echo "1. Verify new quota: gcloud compute regions describe us-central1 --format='yaml(quotas)' | grep -A 2 CPUS"
echo "2. Deploy with full resources: ./deploy-secure.sh"
echo "3. Monitor scaling: kubectl get pods -n webui-adk -w"

echo ""
echo -e "${YELLOW}📞 Need help? Contact GCP Support:${NC}"
echo "https://cloud.google.com/support"

echo ""
read -p "Would you like to open the GCP Console Quotas page now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🌐 Opening GCP Console...${NC}"
    open "https://console.cloud.google.com/iam-admin/quotas?project=$(gcloud config get-value project)"
fi
