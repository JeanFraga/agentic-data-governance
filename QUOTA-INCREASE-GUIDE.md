# GCP CPU Quota Increase Guide

## Current Situation
- **Region**: us-central1
- **Current CPU Quota**: 24 CPUs
- **Current Usage**: 16 CPUs (ek-standard-16 node)
- **Available**: 8 CPUs remaining
- **Issue**: GKE Autopilot trying to scale up but would exceed quota

## Solution 1: Request Quota Increase (Recommended)

### Steps to Request Quota Increase:

1. **Go to GCP Console**:
   ```
   https://console.cloud.google.com/iam-admin/quotas
   ```

2. **Filter for CPU Quotas**:
   - In the quotas page, filter by:
     - Service: "Compute Engine API"
     - Region: "us-central1" 
     - Metric: "CPUs"

3. **Request Increase**:
   - Select the "CPUs" quota for us-central1
   - Click "EDIT QUOTAS"
   - Increase limit to **64 CPUs** or **96 CPUs**
   - Provide justification: "Running production AI application with GKE Autopilot that requires additional compute for scaling"

4. **Wait for Approval**:
   - Usually approved within 24-48 hours for reasonable requests
   - Monitor via GCP Console notifications

### Why This is the Best Solution:
- Allows proper autoscaling for production workloads
- Future-proof for growth
- No architecture changes needed
- Maintains optimal performance

## Alternative Solutions (If Quota Increase Not Possible)

### Solution 2: Switch to Different Region
```bash
# Use a region with higher available quota
terraform apply -var="region=us-east1"
```

### Solution 3: Optimize Resource Requests
- Reduce CPU requests in Helm values
- Use smaller node types
- Implement resource limits more aggressively

### Solution 4: Multi-Regional Deployment
- Split workloads across multiple regions
- Use regional load balancing

## Check Current Quotas
```bash
# Check regional CPU quota
gcloud compute regions describe us-central1 --format="yaml(quotas)" | grep -A 3 -B 3 CPUS

# Check project-wide quotas
gcloud compute project-info describe --format="yaml(quotas)" | grep -A 5 -B 5 CPUS
```

## Monitor Quota Usage
```bash
# Watch quota usage in real-time
watch 'gcloud compute regions describe us-central1 --format="table(quotas.metric,quotas.usage,quotas.limit)" | grep CPUS'
```

## Next Steps
1. **Immediate**: Request quota increase to 64-96 CPUs
2. **Short-term**: Continue with deployment after quota approval
3. **Long-term**: Monitor usage and plan for future scaling needs
