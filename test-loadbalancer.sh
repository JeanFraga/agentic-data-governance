#!/bin/bash

# Quick OpenWebUI-only deployment to test LoadBalancer
# This deploys just OpenWebUI without the custom backend to verify connectivity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Quick OpenWebUI Test Deployment${NC}"
echo "=============================================="

# Check if kubectl is working
if ! kubectl get nodes >/dev/null 2>&1; then
    echo -e "${RED}❌ kubectl not configured properly${NC}"
    exit 1
fi

echo -e "${GREEN}✅ kubectl is working${NC}"

# Create a simple OpenWebUI deployment
echo -e "${BLUE}📦 Creating OpenWebUI test deployment...${NC}"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openwebui-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openwebui-test
  template:
    metadata:
      labels:
        app: openwebui-test
    spec:
      containers:
      - name: openwebui
        image: ghcr.io/open-webui/open-webui:main
        ports:
        - containerPort: 8080
        env:
        - name: OLLAMA_BASE_URL
          value: "https://api.openai.com/v1"
        - name: WEBUI_AUTH
          value: "false"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: openwebui-test
  namespace: default
spec:
  selector:
    app: openwebui-test
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openwebui-test
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openwebui-test
            port:
              number: 80
EOF

echo -e "${GREEN}✅ Deployment created${NC}"

# Wait for deployment to be ready
echo -e "${BLUE}⏳ Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available deployment/openwebui-test --timeout=300s

# Check pod status
echo -e "${BLUE}📋 Pod status:${NC}"
kubectl get pods -l app=openwebui-test

# Check service status
echo -e "${BLUE}🌐 Service status:${NC}"
kubectl get svc openwebui-test

# Check ingress status
echo -e "${BLUE}🔗 Ingress status:${NC}"
kubectl get ingress openwebui-test

echo ""
echo -e "${GREEN}✅ Test deployment complete!${NC}"
echo ""
echo -e "${BLUE}🧪 Testing connectivity:${NC}"

# Get LoadBalancer IP
INGRESS_IP="34.133.61.91"

# Wait a moment for ingress to be ready
sleep 10

# Test HTTP connectivity
echo "Testing HTTP connectivity to $INGRESS_IP..."
if curl -I --connect-timeout 10 "http://$INGRESS_IP" 2>/dev/null | head -1; then
    echo -e "${GREEN}✅ LoadBalancer is responding!${NC}"
else
    echo -e "${YELLOW}⚠️ LoadBalancer may still be configuring...${NC}"
fi

echo ""
echo -e "${BLUE}📋 Access Information:${NC}"
echo "🔗 LoadBalancer IP: http://$INGRESS_IP"
echo "🌐 Direct service access: kubectl port-forward svc/openwebui-test 8080:80"
echo ""
echo -e "${YELLOW}📝 To access via port-forward:${NC}"
echo "   kubectl port-forward svc/openwebui-test 8080:80"
echo "   Then open: http://localhost:8080"
echo ""
echo -e "${BLUE}🔍 Monitor deployment:${NC}"
echo "   kubectl get pods -l app=openwebui-test"
echo "   kubectl logs -l app=openwebui-test"
echo ""
echo -e "${BLUE}🗑️ Clean up test deployment:${NC}"
echo "   kubectl delete deployment,service,ingress openwebui-test"
