# Agentic Data Governance

A production-ready AI application integrating OpenWebUI with Google Agent Development Kit (ADK) backend, deployed on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) principles.

## Architecture

The application consists of three main components:

1. **OpenWebUI Frontend** - Modern web interface for AI interactions
2. **Ollama Proxy** - Translation layer converting OpenWebUI requests to ADK format
3. **ADK Backend** - Google Agent Development Kit service with advanced AI capabilities

## Quick Start

### Script Runner

For easy access to all deployment and management scripts:

```bash
# List all available scripts
./run-script.sh

# Run a specific script
./run-script.sh check-env-simple
./run-script.sh deploy-secure
./run-script.sh test-domain-setup
```

📖 **Detailed Script Documentation**: See [`scripts/README.md`](./scripts/README.md) for comprehensive usage instructions and [`scripts/QUICK-REFERENCE.md`](./scripts/QUICK-REFERENCE.md) for a handy reference card.

### Local Development with Docker Compose

For local development and testing:

```bash
cd adk-backend
./start-ollama-stack.sh
```

This starts all services locally with health checks and automatic setup.

### Production Deployment on Kubernetes

For production deployment using the unified Terraform workflow:

```bash
# Use the unified management script
./scripts/adk-mgmt.sh deploy production

# Or preview first with dry-run
./scripts/adk-mgmt.sh deploy production --dry-run
```

📖 **Complete Deployment Guide**: See [`UNIFIED-DEPLOYMENT-GUIDE.md`](./UNIFIED-DEPLOYMENT-GUIDE.md) for the comprehensive unified deployment workflow.

## Documentation

- **[Unified Deployment Guide](./UNIFIED-DEPLOYMENT-GUIDE.md)** - **NEW**: Single workflow for local and production
- **[Local Development Guide](./adk-backend/README.ollama-setup.md)** - Docker Compose setup  
- **[Kubernetes Deployment Guide](./KUBERNETES-DEPLOYMENT.md)** - Legacy production deployment
- **[Ollama Integration Summary](./adk-backend/OLLAMA-SETUP-SUMMARY.md)** - Architecture overview

## Project Structure

```
├── adk-backend/                 # Core application services
│   ├── ollama_proxy.py         # Ollama API translation layer
│   ├── Dockerfile              # ADK backend container
│   ├── Dockerfile.ollama-proxy # Ollama proxy container
│   └── docker-compose.openwebui.yml
├── scripts/                    # Deployment and management scripts
│   ├── adk-mgmt.sh             # **NEW**: Unified management script  
│   ├── deploy-secure.sh        # Legacy: Secure Helm deployment
│   ├── setup-dns.sh           # DNS configuration
│   ├── test-*.sh              # Testing and validation scripts
│   └── README.md              # Scripts documentation
├── terraform/                  # **UNIFIED**: Infrastructure as Code
│   ├── main.tf                 # Environment-aware GKE and local resources
│   ├── variables.tf            # Merged configuration variables
│   ├── terraform.tfvars.local # Local environment config
│   ├── backend-*.tf.template   # Backend configuration templates
│   └── terraform.tfvars.example
├── webui-adk-chart/            # Helm chart for Kubernetes
│   ├── templates/              # Kubernetes manifests
│   └── values.yaml             # Configuration values
└── .github/workflows/          # CI/CD pipeline
    └── deploy.yml              # Automated deployment
```

## Features

- **🚀 Production-Ready**: Fully automated CI/CD with Terraform and Helm
- **🔒 Secure**: OAuth integration, Workload Identity Federation, SSL termination
- **📊 Scalable**: GKE Autopilot with automatic scaling
- **🛠️ Developer-Friendly**: Local development environment with Docker Compose
- **🔧 Infrastructure as Code**: Complete infrastructure defined in Terraform

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd agentic-data-governance
   ```

2. **Choose your deployment method:**
   - **Unified Workflow (Recommended)**: Follow [Unified Deployment Guide](./UNIFIED-DEPLOYMENT-GUIDE.md)
   - **Local Development**: Follow [Local Development Guide](./adk-backend/README.ollama-setup.md)
   - **Legacy Production**: Follow [Kubernetes Deployment Guide](./KUBERNETES-DEPLOYMENT.md)

## Support

For deployment issues:
- Check the relevant deployment guide
- Review logs in your chosen environment
- Verify configuration values match your setup

## License

[Add your license information here]