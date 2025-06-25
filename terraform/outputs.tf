# Environment information
output "environment" {
  value       = var.environment
  description = "The deployment environment (local or production)."
}

output "namespace" {
  value       = local.namespace
  description = "The Kubernetes namespace used for deployment."
}

output "release_name" {
  value       = local.release_name
  description = "The Helm release name."
}

# Production-only outputs
output "gke_cluster_name" {
  value       = local.is_production && length(google_container_cluster.primary) > 0 ? google_container_cluster.primary[0].name : null
  description = "The name of the GKE cluster (production only)."
}

output "artifact_registry_repository" {
  value       = local.is_production && length(google_artifact_registry_repository.adk_repo) > 0 ? google_artifact_registry_repository.adk_repo[0].name : null
  description = "The name of the Artifact Registry repository (production only)."
}

output "adk_image_uri" {
  value       = local.is_production && length(google_artifact_registry_repository.adk_repo) > 0 ? "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo[0].repository_id}/${local.adk_image_name}:${var.adk_image_tag}" : null
  description = "The full URI of the ADK backend Docker image (production only)."
}

output "ollama_image_uri" {
  value       = local.is_production && length(google_artifact_registry_repository.adk_repo) > 0 ? "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo[0].repository_id}/${local.ollama_image_name}:${var.ollama_image_tag}" : null
  description = "The full URI of the Ollama proxy Docker image (production only)."
}

output "ingress_ip" {
  description = "The external IP address of the NGINX Ingress Controller (production only)."
  value = local.is_production && var.deploy_kubernetes_resources ? try(
    data.kubernetes_service.ingress_nginx_controller[0].status[0].load_balancer[0].ingress[0].ip,
    "IP not available yet. Check status with 'kubectl get svc -n ingress-nginx'"
  ) : null
}

# Local-specific outputs
output "local_access_url" {
  value       = local.is_local ? "http://localhost:${var.local_nodeport}" : null
  description = "Direct access URL for local deployment via NodePort."
}

output "kubectl_context" {
  value       = local.is_local ? "docker-desktop" : "gcp-gke-cluster"
  description = "The kubectl context being used."
}

# Domain and DNS outputs (production only)
output "dns_zone_name_servers" {
  description = "The name servers for the DNS zone (configure these at your domain registrar)."
  value       = local.is_production && var.create_dns_zone ? google_dns_managed_zone.domain_zone[0].name_servers : []
}

output "app_url" {
  description = "The URL where your application will be accessible."
  value = local.is_production && var.deploy_kubernetes_resources ? (
    var.enable_https ? "https://${var.app_host}" : "http://${var.app_host}"
  ) : (local.is_local ? "http://localhost:${var.local_nodeport}" : null)
}

output "dns_zone_id" {
  description = "The ID of the DNS zone (if created)."
  value       = local.is_production && var.create_dns_zone ? google_dns_managed_zone.domain_zone[0].id : null
}

output "domain_setup_complete" {
  description = "Whether domain setup is complete and DNS records are created."
  value       = local.is_production && var.create_dns_zone && var.deploy_kubernetes_resources
}