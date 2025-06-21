# Local Helm Deployment Management Commands

## Basic Status Commands
kubectl get all -n webui-adk-local                    # View all resources
kubectl get pods -n webui-adk-local                   # Check pod status
kubectl get svc -n webui-adk-local                    # Check service status

## Logs and Debugging
kubectl logs -n webui-adk-local <pod-name> -c open-webui     # Open WebUI logs
kubectl logs -n webui-adk-local <pod-name> -c adk-backend    # ADK Backend logs
kubectl logs -n webui-adk-local <pod-name> --all-containers  # All container logs
kubectl describe pod -n webui-adk-local <pod-name>           # Pod details

## Port Forwarding (Alternative Access)
kubectl port-forward -n webui-adk-local svc/webui-adk-local-service 8080:80

## Helm Management
helm list -n webui-adk-local                          # List releases
helm status webui-adk-local -n webui-adk-local        # Release status
helm get values webui-adk-local -n webui-adk-local    # View current values

## Upgrading the Deployment
# After making changes to the chart:
helm upgrade webui-adk-local . --namespace webui-adk-local --values values-local.yaml

## Uninstalling
helm uninstall webui-adk-local -n webui-adk-local     # Remove the release
kubectl delete namespace webui-adk-local              # Remove the namespace

## Rebuilding ADK Backend
# If you make changes to the ADK backend code:
cd "../adk-backend"
docker build -t adk-backend:local .
# Then upgrade the helm release to restart pods with new image

## Testing Connectivity
curl -I http://localhost:30080                        # Test NodePort
curl -I http://localhost:8080                         # Test port forward
