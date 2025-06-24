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

For production deployment on GKE:

1. **Configure GitHub Secrets** (see [KUBERNETES-DEPLOYMENT.md](./KUBERNETES-DEPLOYMENT.md))
2. **Push to main branch** - GitHub Actions will automatically deploy
3. **Configure DNS** - Point your domain to the ingress IP

## Documentation

- **[Local Development Guide](./adk-backend/README.ollama-setup.md)** - Docker Compose setup
- **[Kubernetes Deployment Guide](./KUBERNETES-DEPLOYMENT.md)** - Production deployment
- **[Ollama Integration Summary](./adk-backend/OLLAMA-SETUP-SUMMARY.md)** - Architecture overview

## Project Structure

```
├── adk-backend/                 # Core application services
│   ├── ollama_proxy.py         # Ollama API translation layer
│   ├── Dockerfile              # ADK backend container
│   ├── Dockerfile.ollama-proxy # Ollama proxy container
│   └── docker-compose.openwebui.yml
├── scripts/                    # Utility scripts for deployment and testing
│   ├── deploy-secure.sh        # Secure Helm deployment
│   ├── setup-dns.sh           # DNS configuration
│   ├── test-*.sh              # Testing and validation scripts
│   └── README.md              # Scripts documentation
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                 # GKE cluster and resources
│   ├── variables.tf            # Configuration variables
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
   - **Local Development**: Follow [Local Development Guide](./adk-backend/README.ollama-setup.md)
   - **Production**: Follow [Kubernetes Deployment Guide](./KUBERNETES-DEPLOYMENT.md)

## Support

For deployment issues:
- Check the relevant deployment guide
- Review logs in your chosen environment
- Verify configuration values match your setup

## License

[Add your license information here]