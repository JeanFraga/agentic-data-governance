output "namespace" {
  description = "The Kubernetes namespace where ADK is deployed"
  value       = kubernetes_namespace.adk_local.metadata[0].name
}

output "release_name" {
  description = "The Helm release name"
  value       = helm_release.adk_local.name
}

output "port_forward_command" {
  description = "Command to port-forward to the local service"
  value       = "kubectl port-forward -n ${kubernetes_namespace.adk_local.metadata[0].name} svc/${helm_release.adk_local.name}-open-webui 8080:80"
}

output "nodeport_access" {
  description = "Access via NodePort (if using Docker Desktop)"
  value       = "http://localhost:30080"
}

output "kubectl_context" {
  description = "Kubernetes context being used"
  value       = "docker-desktop"
}
