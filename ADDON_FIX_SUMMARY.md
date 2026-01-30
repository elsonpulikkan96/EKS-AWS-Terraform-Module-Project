# EKS Add-on Fix Summary - EKS 1.35 Compatibility

## Changes Made

### 1. Updated Add-on Versions (All Environments)
All three environment files (`dev.tfvars`, `stage.tfvars`, `prod.tfvars`) now use EKS 1.35-compatible versions:

| Add-on | Version |
|--------|---------|
| vpc-cni | v1.21.1-eksbuild.3 |
| coredns | v1.13.1-eksbuild.1 |
| kube-proxy | v1.35.0-eksbuild.2 |
| aws-efs-csi-driver | v2.3.0-eksbuild.1 |
| aws-ebs-csi-driver | v1.55.0-eksbuild.1 |

### 2. Fixed EBS CSI Driver IAM Role (Critical Fix)

**Root Cause of Timeout Error:**
The EBS CSI driver was using the node role (`eks_node_role_arn`) instead of a dedicated OIDC-based service account role. This caused permission issues and 20-minute timeouts.

**Solution Implemented:**

#### A. Created Dedicated IAM Role (`modules/iam/main.tf`)
```hcl
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${local.cluster_name}-ebs-csi-driver-role-${random_integer.random_suffix.result}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}
```

This role:
- Uses OIDC federation (not EC2 assume role)
- Trusts the specific service account: `system:serviceaccount:kube-system:ebs-csi-controller-sa`
- Validates the audience is `sts.amazonaws.com`

#### B. Updated Add-on Configuration (`modules/eks/main.tf`)
```hcl
service_account_role_arn = each.value.name == "aws-ebs-csi-driver" ? var.ebs_csi_driver_role_arn : null
```

Now correctly uses the dedicated OIDC role instead of the node role.

## Potential Pitfalls & Recommendations

### 1. **State Management - CRITICAL**
⚠️ **If you have existing add-ons in a failed state:**

```bash
# Check current state
terraform workspace select dev
terraform state list | grep aws_eks_addon

# If EBS CSI driver is stuck, you may need to:
# Option A: Import existing addon (if it exists in AWS)
terraform import 'module.eks.aws_eks_addon.eks-addons["4"]' testing-spectrio-test-eks-cluster:aws-ebs-csi-driver

# Option B: Remove from state and recreate
terraform state rm 'module.eks.aws_eks_addon.eks-addons["4"]'
```

### 2. **Deployment Order**
The fix ensures proper dependency chain:
1. VPC & Subnets created
2. IAM roles created (including EBS CSI driver role)
3. EKS cluster created
4. OIDC provider created
5. Node groups created
6. Add-ons installed (with proper IAM roles)

### 3. **OIDC Provider Timing**
The EBS CSI driver role depends on the OIDC provider being created first. The current code handles this via:
- OIDC provider created in `modules/eks/main.tf` after cluster
- IAM module depends on EKS module outputs
- Add-ons depend on node groups

### 4. **Version Pinning Trade-offs**
✅ **Pros:**
- Predictable deployments
- No surprise breaking changes
- Easier troubleshooting

⚠️ **Cons:**
- Manual updates required for security patches
- Need to monitor AWS release notes

**Recommendation:** Set up a quarterly review process to check for new addon versions.

### 5. **Multi-Environment Consistency**
All three environments now use identical addon versions. Consider:
- Testing version upgrades in `dev` first
- Promoting to `stage` after validation
- Finally updating `prod`

### 6. **Addon Installation Time**
Even with the fix, addons can take 5-10 minutes to become ACTIVE:
- `vpc-cni`: ~2-3 minutes
- `coredns`: ~3-5 minutes
- `kube-proxy`: ~2-3 minutes
- `aws-efs-csi-driver`: ~3-5 minutes
- `aws-ebs-csi-driver`: ~5-10 minutes (slowest)

The 30-minute timeout should be sufficient.

### 7. **Conflict Resolution**
The configuration uses `OVERWRITE` for conflict resolution:
```hcl
resolve_conflicts_on_create = "OVERWRITE"
resolve_conflicts_on_update = "OVERWRITE"
```

This means Terraform will overwrite any manual changes made to addons via AWS Console or kubectl.

### 8. **Service Account Verification**
After deployment, verify the EBS CSI driver service account:

```bash
# Check service account exists
kubectl get sa ebs-csi-controller-sa -n kube-system

# Verify IAM role annotation
kubectl describe sa ebs-csi-controller-sa -n kube-system | grep eks.amazonaws.com/role-arn

# Check EBS CSI driver pods
kubectl get pods -n kube-system -l app=ebs-csi-controller
```

### 9. **Rollback Strategy**
If issues occur:

```bash
# Remove problematic addon
terraform workspace select dev
terraform destroy -target='module.eks.aws_eks_addon.eks-addons["4"]' -var-file="dev.tfvars"

# Fix and reapply
terraform apply -var-file="dev.tfvars"
```

### 10. **Monitoring Add-on Health**
```bash
# Check addon status
aws eks describe-addon \
  --cluster-name testing-spectrio-test-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1

# Check for issues
aws eks describe-addon \
  --cluster-name testing-spectrio-test-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1 \
  --query 'addon.health.issues'
```

## Deployment Steps

### For Fresh Deployment:
```bash
terraform workspace select dev
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars" -auto-approve
```

### For Existing Cluster with Failed Add-on:
```bash
# 1. Check current state
terraform workspace select dev
terraform state list | grep aws_eks_addon

# 2. If EBS CSI addon exists but failed, remove it
terraform state rm 'module.eks.aws_eks_addon.eks-addons["4"]'

# 3. Apply with new configuration
terraform apply -var-file="dev.tfvars" -auto-approve

# 4. Verify addon status
aws eks describe-addon \
  --cluster-name testing-spectrio-test-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1
```

## Testing EBS CSI Driver

After successful deployment, test the EBS CSI driver:

```bash
# Create a test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-test-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 4Gi
EOF

# Check PVC status
kubectl get pvc ebs-test-claim

# Should show STATUS: Bound
# Clean up
kubectl delete pvc ebs-test-claim
```

## Files Modified

1. `modules/iam/main.tf` - Added EBS CSI driver OIDC role
2. `modules/iam/outputs.tf` - Added EBS CSI driver role ARN output
3. `modules/eks/variables.tf` - Added EBS CSI driver role ARN variable
4. `modules/eks/main.tf` - Updated addon configuration to use dedicated role
5. `main.tf` - Passed EBS CSI driver role ARN to EKS module
6. `dev.tfvars` - Updated addon versions
7. `stage.tfvars` - Updated addon versions
8. `prod.tfvars` - Updated addon versions

## Additional Notes

- The node role still has `AmazonEBSCSIDriverPolicy` attached (line 68-72 in `modules/iam/main.tf`). This is harmless but not used by the addon.
- The dedicated OIDC role is the correct approach per AWS best practices.
- All addon versions are officially supported for EKS 1.35.
