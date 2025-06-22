output "gke_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster."
}

output "artifact_registry_repository" {
  value       = google_artifact_registry_repository.adk_repo.name
  description = "The name of the Artifact Registry repository."
}

output "adk_image_uri" {
  value       = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo.repository_id}/${local.adk_image_name}:${var.adk_image_tag}"
  description = "The full URI of the ADK backend Docker image."
}

output "ollama_image_uri" {
  value       = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.adk_repo.repository_id}/${local.ollama_image_name}:${var.ollama_image_tag}"
  description = "The full URI of the Ollama proxy Docker image."
}

output "ingress_ip" {
  description = "The external IP address of the NGINX Ingress Controller."
  value = var.deploy_kubernetes_resources ? try(
    data.kubernetes_service.ingress_nginx_controller[0].status[0].load_balancer[0].ingress[0].ip,
    "IP not available yet. Check status with 'kubectl get svc -n ingress-nginx'"
  ) : "Kubernetes resources not deployed"
}

# Domain and DNS outputs
output "dns_zone_name_servers" {
  description = "The name servers for the DNS zone (configure these at your domain registrar)."
  value = var.create_dns_zone ? google_dns_managed_zone.domain_zone[0].name_servers : []
}

output "app_url" {
  description = "The URL where your application will be accessible."
  value = var.deploy_kubernetes_resources ? (
    var.enable_https ? "https://${var.app_host}" : "http://${var.app_host}"
  ) : "Application not deployed yet"
}

output "dns_zone_id" {
  description = "The ID of the DNS zone (if created)."
  value = var.create_dns_zone ? google_dns_managed_zone.domain_zone[0].id : null
}

output "domain_setup_complete" {
  description = "Whether domain setup is complete and DNS records are created."
  value = var.create_dns_zone && var.deploy_kubernetes_resources
}