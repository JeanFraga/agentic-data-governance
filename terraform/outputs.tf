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
  value = try(
    data.kubernetes_service.ingress_nginx_controller.status.load_balancer.ingress.ip,
    "IP not available yet. Check status with 'kubectl get svc -n ingress-nginx'"
  )
}

data "kubernetes_service" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = helm_release.ingress_nginx.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}