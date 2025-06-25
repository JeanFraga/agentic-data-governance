terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.10.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
  }
}

# Google provider - configured for production, ignored for local
provider "google" {
  project = var.environment == "production" ? var.gcp_project_id : null
  region  = var.environment == "production" ? var.gcp_region : null
}

locals {
  # Environment-specific configurations
  is_production = var.environment == "production"
  is_local      = var.environment == "local"

  # Image configurations
  adk_image_name    = "adk-backend"
  ollama_image_name = "ollama-proxy"

  # Release name based on environment
  release_name = var.release_name != "" ? var.release_name : (
    local.is_local ? "adk-local" : "webui-adk"
  )

  # Namespace based on environment  
  namespace = local.is_local ? var.namespace : "default"
}

# --- 1. Provision Core GCP Infrastructure (Production Only) ---

# Enable required APIs (Production only)
resource "google_project_service" "dns_api" {
  count   = local.is_production && var.create_dns_zone ? 1 : 0
  service = "dns.googleapis.com"
}

resource "google_project_service" "gke_api" {
  count   = local.is_production ? 1 : 0
  service = "container.googleapis.com"
}

resource "google_project_service" "artifact_registry_api" {
  count   = local.is_production ? 1 : 0
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cloudbuild_api" {
  count   = local.is_production ? 1 : 0
  service = "cloudbuild.googleapis.com"
}

resource "google_artifact_registry_repository" "adk_repo" {
  count         = local.is_production ? 1 : 0
  provider      = google
  repository_id = "webui-adk-repo"
  format        = "DOCKER"
  location      = var.gcp_region
  description   = "Docker repository for the ADK backend service."
  depends_on = [
    google_project_service.artifact_registry_api
  ]
}

# Cloud Build service account for building images
data "google_project" "project" {
  count = local.is_production ? 1 : 0
}

resource "google_project_iam_member" "cloudbuild_artifact_registry" {
  count   = local.is_production ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.project[0].number}@cloudbuild.gserviceaccount.com"
  depends_on = [
    google_project_service.cloudbuild_api
  ]
}

resource "google_project_iam_member" "cloudbuild_logging" {
  count   = local.is_production ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.project[0].number}@cloudbuild.gserviceaccount.com"
  depends_on = [
    google_project_service.cloudbuild_api
  ]
}

resource "google_container_cluster" "primary" {
  count            = local.is_production ? 1 : 0
  name             = "webui-adk-cluster"
  location         = var.gcp_region
  enable_autopilot = true
  depends_on = [
    google_project_service.gke_api
  ]
}

# --- 2. DNS Zone Management (Optional) ---

# Data source to reference existing DNS zone (when not creating new one)
data "google_dns_managed_zone" "existing_zone" {
  count = local.is_production && !var.create_dns_zone && var.domain_name != "" ? 1 : 0
  name  = var.dns_zone_name
}

resource "google_dns_managed_zone" "domain_zone" {
  count       = local.is_production && var.create_dns_zone ? 1 : 0
  name        = var.dns_zone_name
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.domain_name} - managed by Terraform"

  # Enable DNSSEC for security
  dnssec_config {
    state = "on"
  }

  depends_on = [
    google_project_service.dns_api
  ]
}

# Local to get the correct zone name (either created or existing)
locals {
  dns_zone_name = local.is_production ? (
    var.create_dns_zone ? google_dns_managed_zone.domain_zone[0].name : (
      var.domain_name != "" ? data.google_dns_managed_zone.existing_zone[0].name : ""
    )
  ) : ""
}

# Create DNS A record pointing to the ingress IP
resource "google_dns_record_set" "app_a_record" {
  count = local.is_production && (var.create_dns_zone || var.domain_name != "") && var.deploy_kubernetes_resources ? 1 : 0

  name         = var.app_host == "" ? "${var.domain_name}." : "${var.app_host}."
  managed_zone = local.dns_zone_name
  type         = "A"
  ttl          = 300

  rrdatas = length(data.kubernetes_service.ingress_nginx_controller) > 0 ? [data.kubernetes_service.ingress_nginx_controller[0].status[0].load_balancer[0].ingress[0].ip] : ["0.0.0.0"]

  depends_on = [
    helm_release.ingress_nginx,
    google_dns_managed_zone.domain_zone,
    data.google_dns_managed_zone.existing_zone
  ]
}

# Optional: Create CNAME record for www subdomain
resource "google_dns_record_set" "www_cname_record" {
  count = var.create_dns_zone && var.domain_name != "" && var.app_host == var.domain_name ? 1 : 0

  name         = "www.${var.domain_name}."
  managed_zone = local.dns_zone_name
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["${var.domain_name}."]

  depends_on = [
    google_dns_managed_zone.domain_zone,
    google_dns_record_set.app_a_record
  ]
}

# --- 3. Configure Authentication (IAM and Workload Identity Federation) ---

resource "google_service_account" "github_actions_sa" {
  count        = local.is_production && var.github_repo != "" ? 1 : 0
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

resource "google_project_iam_member" "artifact_writer" {
  count   = local.is_production && var.github_repo != "" ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa[0].email}"
}

resource "google_project_iam_member" "gke_developer" {
  count   = local.is_production && var.github_repo != "" ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions_sa[0].email}"
}

resource "google_iam_workload_identity_pool" "github_pool" {
  count                     = local.is_production && var.github_repo != "" ? 1 : 0
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  count                              = local.is_production && var.github_repo != "" ? 1 : 0
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions Provider"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "assertion.repository=='${var.github_repo}'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "wif_binding" {
  count              = local.is_production && var.github_repo != "" ? 1 : 0
  service_account_id = google_service_account.github_actions_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool[0].name}/attribute.repository/${var.github_repo}"
}

# --- 3. Deploy Application to GKE using Helm ---

# Data sources - conditional for production
data "google_client_config" "default" {
  count = local.is_production ? 1 : 0
}

# Data source for ingress controller service (used by DNS records)
data "kubernetes_service" "ingress_nginx_controller" {
  count = local.is_production && var.deploy_kubernetes_resources ? 1 : 0
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.ingress_nginx]
}

# Kubernetes and Helm providers
# Note: For local deployment, ensure kubectl context is set to docker-desktop  
provider "helm" {
  kubernetes = {
    config_path    = local.is_local ? "~/.kube/config" : null
    config_context = local.is_local ? "docker-desktop" : null

    host                   = local.is_production ? "https://${google_container_cluster.primary[0].endpoint}" : null
    token                  = local.is_production ? data.google_client_config.default[0].access_token : null
    cluster_ca_certificate = local.is_production ? base64decode(google_container_cluster.primary[0].master_auth[0].cluster_ca_certificate) : null
  }
}

provider "kubernetes" {
  config_path    = local.is_local ? "~/.kube/config" : null
  config_context = local.is_local ? "docker-desktop" : null

  host                   = local.is_production ? "https://${google_container_cluster.primary[0].endpoint}" : null
  token                  = local.is_production ? data.google_client_config.default[0].access_token : null
  cluster_ca_certificate = local.is_production ? base64decode(google_container_cluster.primary[0].master_auth[0].cluster_ca_certificate) : null
}

resource "helm_release" "ingress_nginx" {
  count            = var.deploy_kubernetes_resources ? 1 : 0
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
}

resource "helm_release" "cert_manager" {
  count            = var.deploy_cert_manager && var.deploy_kubernetes_resources ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set = [{
    name  = "installCRDs"
    value = "true"
  }]
}

# Wait for cert-manager to be ready and create ClusterIssuer
resource "null_resource" "wait_for_cert_manager" {
  count      = var.deploy_cert_manager && var.deploy_kubernetes_resources ? 1 : 0
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/name=cert-manager --timeout=300s
      
      cat <<EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: letsencrypt-prod
      spec:
        acme:
          server: https://acme-v02.api.letsencrypt.org/directory
          email: ${var.tls_email != "" ? var.tls_email : "admin@example.com"}
          privateKeySecretRef:
            name: letsencrypt-prod-key
          solvers:
          - http01:
              ingress:
                class: nginx
      EOF
    EOT
  }
}

# --- 3. GKE Service Account with proper IAM permissions ---

# Create a dedicated service account for the ADK workload (Production only)
resource "google_service_account" "adk_workload_sa" {
  count        = local.is_production ? 1 : 0
  account_id   = "adk-workload-sa"
  display_name = "ADK Workload Service Account"
  description  = "Service account for ADK backend with Vertex AI permissions"
}

# Grant necessary permissions to the service account (Production only)
resource "google_project_iam_member" "adk_vertex_user" {
  count   = local.is_production ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.adk_workload_sa[0].email}"
}

resource "google_project_iam_member" "adk_vertex_admin" {
  count   = local.is_production ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/aiplatform.admin"
  member  = "serviceAccount:${google_service_account.adk_workload_sa[0].email}"
}

# Allow the Kubernetes service account to impersonate the Google service account (Production only)
resource "google_service_account_iam_member" "adk_workload_identity" {
  count              = local.is_production ? 1 : 0
  service_account_id = google_service_account.adk_workload_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[default/adk-backend-sa]"
}

# Main application deployment - environment aware
resource "helm_release" "webui_adk_app" {
  count     = var.deploy_kubernetes_resources ? 1 : 0
  name      = local.release_name
  chart     = "../webui-adk-chart"
  namespace = local.namespace

  # Use environment-specific set values
  set = concat(
    # Common settings
    [
      {
        name  = "replicaCount"
        value = var.replica_count
      },
      {
        name  = "environment"
        value = var.environment
      },
      {
        name  = "adkBackend.image.repository"
        value = local.is_local ? var.local_image_repository_adk : "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo[0].repository_id}/${local.adk_image_name}"
      },
      {
        name  = "adkBackend.image.tag"
        value = local.is_local ? var.local_image_tag : var.adk_image_tag
      },
      {
        name  = "ollamaProxy.image.repository"
        value = local.is_local ? var.local_image_repository_ollama : "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo[0].repository_id}/${local.ollama_image_name}"
      },
      {
        name  = "ollamaProxy.image.tag"
        value = local.is_local ? var.local_image_tag : var.ollama_image_tag
      },
      {
        name  = "ingress.enabled"
        value = local.is_production && var.app_host != "webui.example.com" && var.app_host != ""
      },
      {
        name  = "openWebUI.service.type"
        value = local.is_local ? "NodePort" : "ClusterIP"
      },
      {
        name  = "openWebUI.auth.enablePasswordLogin"
        value = "true"
      },
      {
        name  = "persistence.size"
        value = local.is_local ? "5Gi" : "10Gi"
      },
      {
        name  = "admin_email"
        value = var.admin_email
      }
    ],
    # Local-specific settings
    local.is_local ? [
      {
        name  = "openWebUI.service.nodePort"
        value = var.local_nodeport
      },
      {
        name  = "openWebUI.sso.enabled"
        value = "false"
      },
      {
        name  = "openWebUI.auth.disableSignup"
        value = "false"
      }
    ] : [],
    # Production-specific settings
    local.is_production ? [
      {
        name  = "app_host"
        value = var.app_host
      },
      {
        name  = "openWebUI.sso.enabled"
        value = var.oauth_client_id != "" ? "true" : "false"
      },
      {
        name  = "openWebUI.auth.disableSignup"
        value = "true"
      },
      {
        name  = "workloadIdentity.gcpServiceAccount"
        value = google_service_account.adk_workload_sa[0].email
      }
    ] : []
  )

  set_sensitive = local.is_production ? [
    {
      name  = "oauth.clientSecret"
      value = var.oauth_client_secret
    }
  ] : []

  depends_on = [
    # Production dependencies
    helm_release.ingress_nginx,
    google_service_account.adk_workload_sa,
    google_project_iam_member.adk_vertex_user,
    google_project_iam_member.adk_vertex_admin,
    # Local dependencies
    kubernetes_namespace.local_namespace
  ]
}

# Local namespace (for local deployments only)
resource "kubernetes_namespace" "local_namespace" {
  count = local.is_local ? 1 : 0

  metadata {
    name = local.namespace
    labels = {
      environment = "local"
      managed-by  = "terraform"
    }
  }
}