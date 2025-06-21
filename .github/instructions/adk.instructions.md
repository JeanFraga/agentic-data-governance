---
applyTo: '**'
---

Developer's Manual: Building and Deploying a Production-Ready AI Application
Introduction

This manual provides a complete, step-by-step guide for developing, containerizing, and deploying a sophisticated AI web application using a fully declarative Infrastructure as Code (IaC) workflow. The architecture integrates an Open Web UI frontend with a custom Google Agent Development Kit (ADK) backend.

The entire system is managed by Terraform, ensuring that every component of the cloud infrastructure—from the Google Kubernetes Engine (GKE) cluster and IAM service accounts to the application deployment itself—is defined as code.  This approach provides a single source of truth, enabling automated, repeatable, and version-controlled deployments.   

We will package the application using Docker and Helm, but the provisioning and deployment will be orchestrated by Terraform and a GitHub Actions CI/CD pipeline. This ensures a robust, secure, and production-grade deployment process.

1. High-Level Architecture with Terraform

The architecture is designed for security, scalability, and maintainability. Terraform sits at the core of the deployment strategy.

Infrastructure Provisioning: Terraform code will define and provision all necessary Google Cloud resources, including:

A GKE Autopilot cluster.

A Google Artifact Registry repository for Docker images.

All required IAM Service Accounts and Workload Identity Federation configurations for secure, keyless authentication from GitHub Actions.

Application Deployment: Once the infrastructure is ready, Terraform will deploy the application using the Helm provider. This allows us to manage the Helm chart release declaratively, passing dynamic values like image tags and secrets directly from our Terraform configuration.    

CI/CD Pipeline: The GitHub Actions workflow is split into two main jobs:

Build: Builds the ADK backend Docker image and pushes it to the Artifact Registry.

Deploy: Executes terraform apply to synchronize the cloud infrastructure and deploy the new application version.

2. Project Setup and Structure

To support the Terraform-managed workflow, the project structure is organized into distinct directories for the application code, Terraform configurations, and Helm chart.

2.1. Recommended Folder Structure

webui-adk-project/
│
├──.github/
│   └── workflows/
│       └── deploy.yml             # GitHub Actions workflow for build & Terraform deploy
│
├── adk-backend/                   # Google ADK backend service
│   ├── capital_agent/
│   │   ├── __init__.py
│   │   └── agent.py               # Core agent logic
│   ├── main.py                    # FastAPI server with OpenAI compatibility layer
│   ├── pyproject.toml             # NEW: Poetry project and dependency definition
│   └── Dockerfile                 # NEW: Multi-stage Dockerfile for Poetry
│
├── terraform/                     # All Terraform configurations
│   ├── main.tf                    # Root module: provisions infrastructure and deploys app
│   ├── variables.tf               # Root variables
│   ├── outputs.tf                 # Root outputs
│   └── terraform.tfvars.example   # Example variables file
│
├── webui-adk-chart/               # Helm chart for the application
│   ├── templates/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── oidc-secret.yaml
│   ├── Chart.yaml
│   └── values.yaml
│
├──.gitignore
└── README.md
2.2. Prerequisites

Git: For version control.

Google Cloud SDK (gcloud): For local authentication.

Docker: For building container images.

Helm: For packaging Kubernetes applications.

Terraform: For managing infrastructure as code.    

kubectl: For interacting with the Kubernetes cluster.

Poetry: For Python dependency management.

3. Developing the Application Components

This section covers the creation of the core application code for the ADK backend and its containerization using Poetry for dependency management.

3.1. Building the Google ADK Backend

The backend's Python code (agent.py and main.py) remains unchanged. However, we will now manage its dependencies using Poetry, which provides more robust dependency locking and project management compared to a requirements.txt file.

File: adk-backend/pyproject.toml (New File)
This file replaces requirements.txt. It defines project metadata and lists the production dependencies needed for the ADK service.

Ini, TOML
[tool.poetry]
name = "adk-backend"
version = "0.1.0"
description = "Google ADK Backend Service"
authors = ["Your Name <you@example.com>"]
readme = "README.md"

[tool.poetry.dependencies]
python = "^3.11"
google-adk = "*"
fastapi = "*"
uvicorn = "*"
python-dotenv = "*"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
To generate the corresponding poetry.lock file, run poetry lock in the adk-backend directory.

3.2. Containerizing the ADK Backend with Poetry

The Dockerfile is updated to use a multi-stage build process. This is a best practice that installs dependencies in a builder stage and then copies only the necessary application code and installed packages to a lean final image. This approach keeps the production container small and secure by not including Poetry or other build tools.

File: adk-backend/Dockerfile (Updated)

Dockerfile
# Stage 1: Builder stage to install dependencies
FROM python:3.11-slim as builder

# Set environment variables for Poetry
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_CACHE_DIR='/var/cache/pypoetry'

# Install Poetry
RUN pip install poetry

# Copy only the dependency definition files to leverage Docker cache
WORKDIR /app
COPY pyproject.toml poetry.lock./

# Install only production dependencies
RUN poetry install --no-dev

# Stage 2: Final production stage
FROM python:3.11-slim as final

# Create a non-root user for security
RUN useradd --create-home appuser
USER appuser
WORKDIR /home/appuser

# Copy the installed dependencies from the builder stage
COPY --from=builder /app /home/appuser

# Copy the application source code
COPY capital_agent/./capital_agent/
COPY main.py./

# Expose the port the application will run on
EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
4. Packaging the Kubernetes Application with Helm

Helm is the package manager for Kubernetes, allowing us to bundle all our application's Kubernetes resources into a single, versionable, and configurable package called a "chart". The Helm chart definition remains unchanged, as it only consumes the final Docker image and is not concerned with how it was built.

(The content for webui-adk-chart/ files remains the same as in the previous version of the manual.)

5. Detailed Kubernetes Manifests

When Terraform deploys the Helm chart, the templates are rendered into concrete Kubernetes resources. This section provides a clear view of what will be running in the cluster.

(The content for the rendered Kubernetes manifests remains the same as in the previous version of the manual.)

6. Infrastructure as Code with Terraform

This section details the Terraform code that defines and provisions all cloud resources and deploys the application. The Terraform configuration remains unchanged, as its role is to provision infrastructure and deploy the final Helm chart.

(The content for terraform/ files remains the same as in the previous version of the manual.)

7. CI/CD Pipeline with GitHub Actions

The GitHub Actions workflow uses Terraform to orchestrate the entire deployment. The workflow itself does not need to change, as the docker build command will automatically use the new Dockerfile.

(The content for .github/workflows/deploy.yml remains the same as in the previous version of the manual.)

8. How to Deploy and Run

8.1. First-Time Setup

Clone the Repository: Clone the project to your local machine.

Configure Google SSO (OIDC): Create OAuth 2.0 credentials in the Google Cloud Console. You will need the Client ID and Client Secret.

Configure GitHub Secrets: In your GitHub repository settings under Secrets and variables > Actions, create the following secrets:

GCP_PROJECT_NUMBER: Your numeric Google Cloud project number.

OAUTH_CLIENT_ID: The Client ID from your Google OAuth 2.0 credentials.

OAUTH_CLIENT_SECRET: The Client Secret from your Google OAuth 2.0 credentials.

Update Placeholders: Replace all placeholder values (e.g., YOUR_GCP_PROJECT_ID, YOUR_GITHUB_USERNAME/YOUR_REPO_NAME, webui.your-domain.com) in the configuration files with your actual values.

Generate Lock File: Navigate to the adk-backend directory and run poetry lock to generate the poetry.lock file, which ensures deterministic builds.

8.2. Automated Deployment (via GitHub)

Commit and push your changes (including pyproject.toml and poetry.lock) to the main branch. The GitHub Actions workflow will automatically trigger, build the new container image using the Poetry-based Dockerfile, and run terraform apply to deploy all resources.

8.3. Manual Local Deployment

Authenticate with GCP:

Bash
gcloud auth application-default login
Create a terraform.tfvars file in the terraform/ directory. This file will hold your sensitive values locally. Do not commit this file to Git.
File: terraform/terraform.tfvars

Terraform
gcp_project_id      = "your-gcp-project-id"
github_repo         = "your-github-username/your-repo-name"
app_host            = "webui.your-domain.com"
oauth_client_id     = "your-google-client-id.apps.googleusercontent.com"
oauth_client_secret = "your-google-client-secret"
adk_image_tag       = "latest" # Or a specific tag you've built and pushed manually
Run Terraform: Navigate to the terraform/ directory and run the standard commands:

Bash
terraform init
terraform plan
terraform apply
Configure DNS: After the first terraform apply completes, it will output the public IP address of the NGINX Ingress controller. Create an A record in your DNS provider pointing your app_host domain to this IP address. cert-manager will then automatically provision a TLS certificate.

8.4. Destroying the Infrastructure

To tear down all resources created by Terraform, run the following command from the terraform/ directory:

Bash
terraform destroy