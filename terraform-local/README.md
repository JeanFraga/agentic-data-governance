# Local Terraform Deployment

This directory contains Terraform configuration for **local development only** using Docker Desktop Kubernetes.

## Purpose

- **Local Testing**: Test the ADK application locally before production deployment
- **Isolation**: Completely separate from GCP production infrastructure
- **Development**: Quick iteration and debugging on local machine

## Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl configured with `docker-desktop` context
- Terraform installed

## Quick Start

```bash
# Ensure you're in the local context
kubectl config use-context docker-desktop

# Initialize and apply
terraform init
terraform plan
terraform apply

# Access the application
kubectl port-forward -n adk-local svc/adk-local 8080:80
# Open http://localhost:8080
```

## Configuration

- **Namespace**: `adk-local` (isolated from production)
- **Replicas**: 1 (lightweight for local testing)
- **Ingress**: Disabled (use port-forward)
- **Context**: `docker-desktop` only

## Clean Up

```bash
terraform destroy
```

## Production Deployment

Production deployment uses the `../terraform/` directory which targets GCP infrastructure. Never mix local and production configurations!
