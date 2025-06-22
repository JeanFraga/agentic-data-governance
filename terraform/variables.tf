variable "gcp_project_id" {
  type        = string
  description = "The Google Cloud project ID."
}

variable "gcp_region" {
  type        = string
  description = "The Google Cloud region for resources."
  default     = "us-central1"
}

variable "github_repo" {
  type        = string
  description = "The GitHub repository in 'owner/repo' format for Workload Identity Federation."
}

variable "app_host" {
  type        = string
  description = "The domain name for the application's ingress."
  default     = "webui.example.com"
}

variable "oauth_client_id" {
  type        = string
  description = "The Google OAuth Client ID for SSO."
  sensitive   = true
}

variable "oauth_client_secret" {
  type        = string
  description = "The Google OAuth Client Secret for SSO."
  sensitive   = true
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

variable "admin_password" {
  type        = string
  description = "The default admin password for OpenWebUI."
  sensitive   = true
}

variable "deploy_kubernetes_resources" {
  type        = bool
  description = "Whether to deploy Kubernetes resources (Helm charts)"
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