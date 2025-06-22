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

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  adk_image_name    = "adk-backend"
  ollama_image_name = "ollama-proxy"
}

# --- 1. Provision Core GCP Infrastructure ---

# Enable required APIs
resource "google_project_service" "dns_api" {
  count   = var.create_dns_zone ? 1 : 0
  service = "dns.googleapis.com"
}

resource "google_project_service" "gke_api" {
  service = "container.googleapis.com"
}
resource "google_project_service" "artifact_registry_api" {
  service = "artifactregistry.googleapis.com"
}

resource "google_artifact_registry_repository" "adk_repo" {
  provider      = google
  repository_id = "webui-adk-repo"
  format        = "DOCKER"
  location      = var.gcp_region
  description   = "Docker repository for the ADK backend service."
  depends_on = [
    google_project_service.artifact_registry_api
  ]
}

resource "google_container_cluster" "primary" {
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
  count = var.create_dns_zone ? 0 : (var.domain_name != "" ? 1 : 0)
  name  = var.dns_zone_name
}

resource "google_dns_managed_zone" "domain_zone" {
  count       = var.create_dns_zone ? 1 : 0
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
  dns_zone_name = var.create_dns_zone ? google_dns_managed_zone.domain_zone[0].name : (
    var.domain_name != "" ? data.google_dns_managed_zone.existing_zone[0].name : ""
  )
}

# Create DNS A record pointing to the ingress IP
resource "google_dns_record_set" "app_a_record" {
  count = (var.create_dns_zone || var.domain_name != "") && var.deploy_kubernetes_resources ? 1 : 0
  
  name         = var.app_host == "" ? "${var.domain_name}." : "${var.app_host}."
  managed_zone = local.dns_zone_name
  type         = "A"
  ttl          = 300

  rrdatas = [data.kubernetes_service.ingress_nginx_controller[0].status[0].load_balancer[0].ingress[0].ip]
  
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
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

resource "google_project_iam_member" "artifact_writer" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "gke_developer" {
  project = var.gcp_project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
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
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}

# --- 3. Deploy Application to GKE using Helm ---

data "google_client_config" "default" {}

# Data source for ingress controller service (used by DNS records)
data "kubernetes_service" "ingress_nginx_controller" {
  count = var.deploy_kubernetes_resources ? 1 : 0
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.ingress_nginx]
}

provider "helm" {
  kubernetes = {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

resource "helm_release" "ingress_nginx" {
  count      = var.deploy_kubernetes_resources ? 1 : 0
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
}

resource "helm_release" "cert_manager" {
  count      = var.deploy_kubernetes_resources ? 1 : 0
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true
  
  set = [{
    name  = "installCRDs"
    value = "true"
  }]
}

# Wait for cert-manager to be ready and create ClusterIssuer
resource "null_resource" "wait_for_cert_manager" {
  count = var.deploy_kubernetes_resources ? 1 : 0
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

# Create a dedicated service account for the ADK workload
resource "google_service_account" "adk_workload_sa" {
  account_id   = "adk-workload-sa"
  display_name = "ADK Workload Service Account"
  description  = "Service account for ADK backend with Vertex AI permissions"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "adk_vertex_user" {
  project = var.gcp_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.adk_workload_sa.email}"
}

resource "google_project_iam_member" "adk_vertex_admin" {
  project = var.gcp_project_id
  role    = "roles/aiplatform.admin"
  member  = "serviceAccount:${google_service_account.adk_workload_sa.email}"
}

# Allow the Kubernetes service account to impersonate the Google service account
resource "google_service_account_iam_member" "adk_workload_identity" {
  service_account_id = google_service_account.adk_workload_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[default/adk-backend-sa]"
}

resource "helm_release" "webui_adk_app" {
  count      = var.deploy_kubernetes_resources ? 1 : 0
  name       = "webui-adk-prod"
  chart      = "../webui-adk-chart"
  namespace  = "default"
  
  values = [
    templatefile("${path.module}/../webui-adk-chart/values.yaml", {
      adk_image_repository    = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo.repository_id}/${local.adk_image_name}"
      adk_image_tag          = var.adk_image_tag
      ollama_image_repository = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo.repository_id}/${local.ollama_image_name}"
      ollama_image_tag       = var.ollama_image_tag
      app_host               = var.app_host
      oauth_client_id        = var.oauth_client_id
      admin_password         = var.admin_password
      enable_ingress         = var.app_host != "webui.example.com" && var.app_host != ""
      enable_tls             = var.enable_https
      tls_email              = var.tls_email
      gcp_project_id         = var.gcp_project_id
    })
  ]

  set_sensitive = [{
    name  = "oauth.clientSecret"
    value = var.oauth_client_secret
  }]

  # Use specific image versions to fix current deployment
  set = [
    {
      name  = "ollamaProxy.image.tag"
      value = "v2.0.0"
    },
    {
      name  = "adkBackend.image.tag"
      value = "latest"
    },
    {
      name  = "workloadIdentity.gcpServiceAccount"
      value = google_service_account.adk_workload_sa.email
    }
  ]

  depends_on = [
    helm_release.ingress_nginx,
    null_resource.wait_for_cert_manager,
    google_service_account.adk_workload_sa,
    google_project_iam_member.adk_vertex_user,
    google_project_iam_member.adk_vertex_admin
  ]
}