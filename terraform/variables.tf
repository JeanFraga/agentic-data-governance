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