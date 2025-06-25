variable "environment" {
  type        = string
  description = "Deployment environment: 'local' for Docker Desktop, 'production' for GCP"
  default     = "production"
  validation {
    condition     = contains(["local", "production"], var.environment)
    error_message = "Environment must be either 'local' or 'production'."
  }
}

variable "gcp_project_id" {
  type        = string
  description = "The Google Cloud project ID. Required for production, optional for local."
  default     = ""
}

variable "gcp_region" {
  type        = string
  description = "The Google Cloud region for resources."
  default     = "us-central1"
}

variable "github_repo" {
  type        = string
  description = "The GitHub repository in 'owner/repo' format for Workload Identity Federation. Required for production."
  default     = ""
}

variable "app_host" {
  type        = string
  description = "The domain name for the application's ingress."
  default     = "webui.example.com"
}

variable "oauth_client_id" {
  type        = string
  description = "The Google OAuth Client ID for SSO. Required for production, optional for local."
  sensitive   = true
  default     = ""
}

variable "oauth_client_secret" {
  type        = string
  description = "The Google OAuth Client Secret for SSO. Required for production, optional for local."
  sensitive   = true
  default     = ""
}

variable "adk_image_tag" {
  type        = string
  description = "The Docker image tag for the ADK backend, typically the Git SHA."
  default     = "latest"
}

variable "ollama_image_tag" {
  type        = string
  description = "The Docker image tag for the Ollama proxy, typically the Git SHA."
  default     = "latest"
}

variable "admin_email" {
  type        = string
  description = "The default admin email for OpenWebUI."
  default     = "admin@example.com"
}

variable "admin_password" {
  type        = string
  description = "The default admin password for OpenWebUI."
  sensitive   = true
  default     = "admin123"
}

variable "replica_count" {
  type        = number
  description = "Number of replicas for the application deployment."
  default     = 1
}

variable "deploy_kubernetes_resources" {
  type        = bool
  description = "Whether to deploy the Kubernetes application resources."
  default     = true
}

variable "deploy_cert_manager" {
  type        = bool
  description = "Whether to deploy cert-manager."
  default     = true
}

# Domain and DNS Configuration
variable "domain_name" {
  type        = string
  description = "The root domain name (e.g., 'example.com'). Leave empty to skip DNS zone creation."
  default     = ""
}

variable "create_dns_zone" {
  type        = bool
  description = "Whether to create a Google Cloud DNS zone for the domain."
  default     = false
}

variable "dns_zone_name" {
  type        = string
  description = "Name for the Google Cloud DNS zone (only used if create_dns_zone is true)."
  default     = "webui-dns-zone"
}

variable "enable_https" {
  type        = bool
  description = "Whether to enable HTTPS/TLS for the ingress"
  default     = true
}

variable "tls_email" {
  type        = string
  description = "Email address for Let's Encrypt TLS certificate"
  default     = "admin@example.com"
}

# Local Development Variables
variable "namespace" {
  type        = string
  description = "Kubernetes namespace for local deployments"
  default     = "adk-local"
}

variable "release_name" {
  type        = string
  description = "Helm release name"
  default     = "" # Will be computed based on environment
}

variable "local_image_repository_adk" {
  type        = string
  description = "Local Docker image repository for ADK backend"
  default     = "adk-backend"
}

variable "local_image_repository_ollama" {
  type        = string
  description = "Local Docker image repository for Ollama proxy"
  default     = "ollama-proxy"
}

variable "local_image_tag" {
  type        = string
  description = "Docker image tag for local development"
  default     = "local"
}

variable "local_nodeport" {
  type        = number
  description = "NodePort for local access"
  default     = 30080
}