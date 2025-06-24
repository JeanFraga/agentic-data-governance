variable "namespace" {
  description = "Kubernetes namespace for local ADK deployment"
  type        = string
  default     = "adk-local"
}

variable "release_name" {
  description = "Helm release name for local deployment"
  type        = string
  default     = "adk-local"
}

variable "replica_count" {
  description = "Number of replicas for local deployment"
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
