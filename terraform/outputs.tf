output "gke_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster."
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