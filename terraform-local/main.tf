terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider for local Docker Desktop
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

# Configure Helm provider for local Docker Desktop
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "docker-desktop"
  }
}

# Create namespace for local development
resource "kubernetes_namespace" "adk_local" {
  metadata {
    name = var.namespace
    labels = {
      environment = "local"
      managed-by  = "terraform"
    }
  }
}

# Deploy the ADK application using Helm
resource "helm_release" "adk_local" {
  name       = var.release_name
  chart      = "../webui-adk-chart"
  namespace  = kubernetes_namespace.adk_local.metadata[0].name

  # Override specific values for local development
  set {
    name  = "replicaCount"
    value = var.replica_count
  }

  set {
    name  = "environment"
    value = "local"
  }

  # Disable ingress for local development (use port-forward instead)
  set {
    name  = "ingress.enabled"
    value = "false"
  }

  # Use simple NodePort service
  set {
    name  = "openWebUI.service.type"
    value = "NodePort"
  }

  set {
    name  = "openWebUI.service.nodePort"
    value = "30080"
  }

  # Disable SSO for local development to avoid OAuth complexity
  set {
    name  = "openWebUI.sso.enabled"
    value = "false"
  }

  # Enable password login for local development
  set {
    name  = "openWebUI.auth.disableSignup"
    value = "false"
  }

  set {
    name  = "openWebUI.auth.enablePasswordLogin"
    value = "true"
  }

  # Use local image names (available from previous builds)
  set {
    name  = "adkBackend.image.repository"
    value = "adk-backend"
  }

  set {
    name  = "adkBackend.image.tag"
    value = "local"
  }

  set {
    name  = "ollamaProxy.image.repository"
    value = "ollama-proxy"
  }

  set {
    name  = "ollamaProxy.image.tag"
    value = "local"
  }

  # Smaller persistence for local
  set {
    name  = "persistence.size"
    value = "5Gi"
  }

  depends_on = [kubernetes_namespace.adk_local]
}
