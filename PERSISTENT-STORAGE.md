# Persistent Storage Configuration

This document explains the persistent storage setup for the OpenWebUI application in the Helm chart.

## Overview

The Helm chart now supports persistent storage for OpenWebUI data, ensuring that user data, chat history, and configurations persist across pod restarts and deployments.

## Components

### 1. PersistentVolumeClaim (PVC)
- **File**: `templates/persistentvolumeclaim.yaml`
- **Purpose**: Requests persistent storage from the cluster
- **Name**: `{release-name}-data-pvc`
- **Default Size**: 5Gi (local), 10Gi (production)

### 2. Volume Configuration
- **Location**: Updated in `templates/deployment.yaml`
- **Mount Point**: `/app/backend/data` (OpenWebUI container)
- **Contents**: Database, cache, uploads, vector database

### 3. Configuration Values

#### Production (`values.yaml`)
```yaml
persistence:
  enabled: true
  storageClass: ""          # Use default storage class
  accessModes:
    - ReadWriteOnce
  size: 10Gi               # 10GB for production
```

#### Local Development (`values-local.yaml`)
```yaml
persistence:
  enabled: true
  storageClass: ""          # Use default storage class
  accessModes:
    - ReadWriteOnce
  size: 5Gi                # 5GB for local development
```

## What Gets Persisted

The persistent volume stores all OpenWebUI application data:

- **Database**: `webui.db` - User accounts, chat history, settings
- **Cache**: Downloaded models and temporary files
- **Uploads**: User-uploaded files and documents
- **Vector Database**: Embeddings and semantic search data

## Benefits

1. **Data Persistence**: User data survives pod restarts and deployments
2. **Consistent Experience**: Users maintain their chat history and settings
3. **Performance**: Cached data improves application startup time
4. **Reliability**: No data loss during cluster maintenance or updates

## Storage Classes

### Local Development (Docker Desktop)
- Uses `hostpath` storage class
- Data stored on the host machine
- Suitable for development and testing

### Production (GKE/Cloud)
- Uses cloud provider's default storage class
- Typically backed by SSD persistent disks
- Provides high availability and backup capabilities

## Management Commands

### Check PVC Status
```bash
kubectl get pvc -n webui-adk-local
```

### Check Storage Usage
```bash
kubectl exec <pod-name> -n webui-adk-local -c open-webui -- df -h /app/backend/data
```

### Backup Data (if needed)
```bash
kubectl exec <pod-name> -n webui-adk-local -c open-webui -- tar -czf - -C /app/backend/data . > backup.tar.gz
```

### Restore Data (if needed)
```bash
kubectl exec <pod-name> -n webui-adk-local -c open-webui -- tar -xzf - -C /app/backend/data < backup.tar.gz
```

## Disabling Persistence

To disable persistence and use temporary storage (emptyDir):

```yaml
persistence:
  enabled: false
```

**Warning**: Disabling persistence will result in data loss when pods are restarted.

## Troubleshooting

### PVC Stuck in Pending
- Check if the storage class exists: `kubectl get storageclass`
- Verify cluster has available storage resources
- Check PVC events: `kubectl describe pvc <pvc-name>`

### Mount Issues
- Verify the pod has proper permissions
- Check volume mount configuration in deployment
- Review pod events: `kubectl describe pod <pod-name>`

### Storage Full
- Monitor storage usage regularly
- Consider increasing the PVC size
- Clean up old data if necessary

## Security Considerations

- Persistent volumes may contain sensitive user data
- Ensure proper backup and encryption policies
- Consider access controls for storage resources
- Regular security audits of stored data
